defmodule AmqpReconnect.Publisher do
  @moduledoc false

  use GenServer

  require Logger

  # --- public functions

  def start_link(_args) do
    GenStage.start_link(__MODULE__, :state_doesnt_matter)
  end
 
  # --- callbacks 

  @impl true
  def init(state) do
    {:consumer, {state, connect()), subscribe_to: [AmqpReconnect.Batcher]}
  end

  @impl true
  def handle_events(events, _from, {state, channel}) do
    
    for events <- batch do
      :ok = AMQP.Basic.publish(channel, "amq.fanout", "#", event)
    end

    {:noreply, [], {state, channel}}
  end

  @impl true
  def terminate(:normal, {_state, channel}) do
    connection = channel.conn
    AMQP.Channel.close(channel)
    AMQP.Connection.close(connection)
    
    :terminate_does_not_return_anything
  end 

  # --- private functions
     
  defp connect() do
    {:ok, connection} = AMQP.Connection.open()
    {:ok, channel} = AMQP.Channel.open(connection)
    channel
  end
end
