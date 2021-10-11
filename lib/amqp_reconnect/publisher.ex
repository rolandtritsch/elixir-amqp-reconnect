defmodule AmqpReconnect.Publisher do
  @moduledoc false

  use GenServer

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  # --- callbacks 

  @impl true
  def init(batch) do
    Process.send_after(self(), :publish, 1_000)
    {:ok, {connect(), batch}}
  end

  @impl true
  def handle_info(:kill, {%AMQP.Channel{pid: cpid}, _batch} = state) do
    Process.exit(cpid, :channel_died)
    {:noreply, state}
  end

  @impl true
  def handle_info(:publish, {_channel, []} = state) do
    {:stop, :normal, state}
  end
  
  @impl true
  def handle_info(:publish, {channel, [event | events]}) do
    Logger.info("Publishing event (#{event}) ...")
    
    :ok = AMQP.Basic.publish(channel, "amq.fanout", "#", event)
    Process.send_after(self(), :publish, 1_000)
    {:noreply, {channel, events}}
  end
     
  defp connect() do
    {:ok, connection} = AMQP.Connection.open()
    {:ok, channel} = AMQP.Channel.open(connection)
    channel
  end
end
