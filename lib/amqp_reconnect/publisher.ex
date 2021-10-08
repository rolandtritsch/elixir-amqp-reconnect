defmodule AmqpReconnect.Publisher do
  @moduledoc false

  use GenServer

  require Logger

  # --- public interface

  def run(), do: GenServer.cast(__MODULE__, :run)
  def kill(), do: GenServer.cast(__MODULE__, :kill)

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  # --- callbacks 

  @impl true
  def init(_args) do
    {:ok, conn} = AMQP.Connection.open()
    {:ok, chan} = AMQP.Channel.open(conn)

    Logger.info(inspect(conn))
    Logger.info(inspect(chan))

    state = %{connection: conn, channel: chan}
    {:ok, state}
  end

  @impl true
  def handle_cast(:run, state) do
    Process.send_after(self(), :publish, 0)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:kill, %{channel: %AMQP.Channel{pid: cpid}} = state) do
    Process.exit(cpid, :channel_died)
    {:noreply, state}
  end

  @impl true
  def handle_info(:publish, %{channel: chan} = state) do
    payload = "payload - #{NaiveDateTime.utc_now}"
    Logger.info("Publish: #{payload}")

    state = try do
      :ok = AMQP.Basic.publish(chan, "amq.fanout", "#", payload)
      state
    catch
      :exit, _ ->
        Logger.info("Basic.publish(): infrastructure_/channel_died. Restarting ...")
        state
    end
          
    Process.send_after(self(), :publish, 1_000)
    {:noreply, state}
  end
end
