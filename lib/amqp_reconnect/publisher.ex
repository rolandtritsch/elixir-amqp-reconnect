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

    channel = try_publish(channel, payload)
          
    Process.send_after(self(), :publish, 1_000)
    {:noreply, {channel, :running}}
  end

  @impl true
  def handle_info(:publish, {channel, state}) do
    {:noreply, {channel, state}}
  end

  # --- private functions
     
  defp connect() do
    {:ok, connection} = AMQP.Connection.open()
    {:ok, channel} = AMQP.Channel.open(connection)
    channel
  end

  defp try_publish(channel, payload) do
    :ok = AMQP.Basic.publish(channel, "amq.fanout", "#", payload)
    channel
  catch
    :exit, _ ->
      Logger.info("Basic.publish(): infrastructure_/channel_died. Restart and retry (once) ...")
      channel = connect()
      :ok = AMQP.Basic.publish(channel, "amq.fanout", "#", payload)
      channel
  end
end
