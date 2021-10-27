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
  def init({batch, batcher_pid}) do
    Process.flag(:trap_exit, :true)
    
    Process.link(batcher_pid)
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

    try do
      :ok = AMQP.Basic.publish(channel, "amq.fanout", "#", event)
    catch
      :exit, {:noproc, _} -> Process.exit(self(), :infrastructure_died)
    end
    
    Process.send_after(self(), :publish, 1_000)
    {:noreply, {channel, events}}
  end
 
  @impl true
  def handle_info({:EXIT, pid, {:shutdown, {:internal_error, 541, reason}}}, state) do
    Logger.info(":exit/#{inspect(reason)} detected (#{inspect(pid)}) ...")
    {:stop, :infrastructure_died, state}
  end
  
  @impl true
  def handle_info({:EXIT, pid, {:noproc, _}}, state) do
    Logger.info(":exit/:noproc detected (#{inspect(pid)}) ...")
    {:stop, :infrastructure_died, state}
  end
  
  @impl true
  def handle_info({:EXIT, pid, reason}, state) do
    Logger.info(":exit/#{inspect(reason)} detected (#{inspect(pid)}) ...")
    {:noreply, state}
  end
  
  @impl true
  def handle_info(info, state) do
    Logger.info("Unexpected info detected (#{inspect(info)}) ...")
    {:noreply, state}
  end
  
  @impl true
  def terminate(:infrastructure_died, _state) do
    Logger.info("Reason :infrastructure_died ...")
   
    :terminate_does_not_return_anything
  end 
  
  @impl true
  def terminate({:noproc, _}, _state) do
    Logger.info("Reason :noproc ...")
   
    :terminate_does_not_return_anything
  end 
  
  @impl true
  def terminate(reason, {channel, _batch}) do
    Logger.info("Reason #{inspect(reason)} ...")
    
    connection = channel.conn    
    AMQP.Channel.close(channel)
    AMQP.Connection.close(connection)
    
    :terminate_does_not_return_anything
  end 

  # --- private functions
     
  defp connect() do
    {:ok, %AMQP.Connection{pid: pid} = connection} = AMQP.Connection.open()
    {:ok, channel} = AMQP.Channel.open(connection)
    Process.link(pid)
    channel
  end
end
