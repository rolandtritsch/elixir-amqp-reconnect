defmodule AmqpReconnect.Publisher do
  @moduledoc false

  use GenServer

  require Logger

  # --- public functions

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  # --- callbacks 

  @impl true
  def init({batch, bpid}) do
    Process.send_after(self(), :publish, 1_000)
    state = {connect(), batch, bpid} 
    {:ok, state}
  end

  @impl true
  def handle_info(:kill, {%AMQP.Channel{pid: cpid}, _batch, _bpid} = state) do
    Process.exit(cpid, :channel_died)
    {:noreply, state}
  end

  @impl true
  def handle_info(:publish, {_channel, [], _bpid} = state) do
    {:stop, :normal, state}
  end
  
  @impl true
  def handle_info(:publish, {channel, [event | events], bpid}) do
    Logger.info("Publishing event (#{event}) ...")

    :ok = AMQP.Basic.publish(channel, "amq.fanout", "#", event)
    
    Process.send_after(self(), :publish, 1_000)

    state = {channel, events, bpid}
    {:noreply, state}
  end
 
  @impl true
  def terminate(:normal, {channel, _batch, bpid}) do
    Process.send_after(bpid, :next, 0)
    
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
