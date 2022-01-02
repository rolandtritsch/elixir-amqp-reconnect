defmodule AmqpReconnect.Publisher do
  @moduledoc false

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
  def init(state) do
    {:consumer, {connect(), state}, subscribe_to: [{AmqpReconnect.Batcher, max_demand: 10}]}
  end

  @impl true
  def handle_events(events, _from, {channel, state}) do
    events |> Enum.each(fn event ->
      Logger.info("Publish: #{event}")
      :ok = AMQP.Basic.publish(channel, "amq.fanout", "#", event)
      Process.sleep(1_000)
    end)

    {:noreply, [], {channel, state}}
  end

  @impl true
  def terminate(:normal, {channel, _state}) do
    connection = channel.conn
    AMQP.Channel.close(channel)
    AMQP.Connection.close(connection)
    
    :terminate_does_not_return_anything
  end 

  # --- private functions
     
  defp connect() do
    {:ok, connection} = AMQP.Connection.open()
    {:ok, %AMQP.Channel{pid: cpid} = channel} = AMQP.Channel.open(connection)
    Process.register(cpid, @channel_name)
    channel
  end
end
