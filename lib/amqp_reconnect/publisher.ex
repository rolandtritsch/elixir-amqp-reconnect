defmodule AmqpReconnect.Publisher do
  @moduledoc """
  This stage publishes batches of events.

  Can be started and stopped at will (this is why it is transient).

  Note: If the publisher dies (e.g. because the channel/infrastructure
  dies) it will be restarted by the supervisor. So far so good. But it
  has lost the batch it failed to process. To make this work we keep
  the batch around in the batcher until it is acked by the publisher.
  See below.
  """

  use GenStage, restart: :transient

  require Logger

  @channel_name :publisher_channel_name

  # --- public functions

  def run(), do: Supervisor.start_child(AmqpReconnect.Supervisor, __MODULE__)
  def kill(), do: Process.exit(Process.whereis(@channel_name), :channel_died)
  def stop() do
    :ok = GenStage.stop(__MODULE__)
    :ok = Supervisor.delete_child(AmqpReconnect.Supervisor, __MODULE__)
  end

  def start_link(_args) do
    GenStage.start_link(__MODULE__, :state_doesnt_matter, name: __MODULE__)
  end
 
  # --- callbacks 

  @impl true
  def init(:state_doesnt_matter) do
    {:consumer, connect(), subscribe_to: [{AmqpReconnect.Batcher, max_demand: 10}]}
  end

  @impl true
  def handle_events(events, _from, channel) do
    events |> Enum.each(fn event ->
      Logger.info("Publish: #{event}")
      :ok = AMQP.Basic.publish(channel, "amq.fanout", "#", event)
      Process.sleep(1_000)
    end)

    # Let the batcher know that we are done with this batch
    :ok = GenStage.call(AmqpReconnect.Batcher, :ack)

    {:noreply, [], channel}
  end

  @impl true
  def terminate(:normal, channel) do
    connection = channel.conn
    AMQP.Channel.close(channel)
    AMQP.Connection.close(connection)
    
    :terminate_does_not_return_anything
  end 

  @impl true
  def terminate(_reason, _channel) do
    :terminate_does_not_return_anything
  end

  # --- private functions
     
  defp connect() do
    {:ok, connection} = AMQP.Connection.open()
    {:ok, %AMQP.Channel{pid: cpid} = channel} = AMQP.Channel.open(connection)

    # Register the channel with a name, so that we can kill it
    Process.register(cpid, @channel_name)

    channel
  end
end
