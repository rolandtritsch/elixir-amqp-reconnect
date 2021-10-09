defmodule AmqpReconnect.Publisher do
  @moduledoc false

  use GenServer

  require Logger

  # --- public interface

  def run(), do: GenServer.cast(__MODULE__, :run)
  def kill(), do: GenServer.cast(__MODULE__, :kill)
  def stop(), do: GenServer.cast(__MODULE__, :stop)

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  # --- callbacks 

  @impl true
  def init(_args) do
    Process.flag(:trap_exit, true)
    {:ok, {connect(), :stopped}}
  end

  @impl true
  def handle_cast(:run, {channel, _}) do
    Process.send_after(self(), :publish, 1_000)
    {:noreply, {channel, :running}}
  end

  @impl true
  def handle_cast(:kill, {%AMQP.Channel{pid: cpid} = channel, state}) do
    Process.exit(cpid, :channel_died)
    {:noreply, {channel, state}}
  end

  @impl true
  def handle_cast(:stop, {channel, _}) do
    {:noreply, {channel, :stopped}}
  end

  @impl true
  def handle_info(:publish, {channel, :running}) do
    payload = "payload - #{NaiveDateTime.utc_now}"
    Logger.info("Publish: #{payload}")

    :ok = AMQP.Basic.publish(channel, "amq.fanout", "#", payload)
    
    Process.send_after(self(), :publish, 1_000)
    {:noreply, {channel, :running}}
  end

  @impl true
  def handle_info(:publish, {channel, state}) do
    {:noreply, {channel, state}}
  end
     
  def handle_info({:EXIT, _pid, _reason}, {_, state}) do
    Logger.info("Basic.publish(): infrastructure_/channel_died. Restarting ...")
    {:noreply, {connect(), state}}
  end
  
  defp connect() do
    {:ok, connection} = AMQP.Connection.open()
    {:ok, channel} = AMQP.Channel.open(connection)
    channel
  end
end
