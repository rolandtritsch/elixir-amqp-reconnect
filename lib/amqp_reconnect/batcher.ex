defmodule AmqpReconnect.Batcher do
  @moduledoc """
  This batcher starts a supervisor and waits for the request
  to start creating batches of payloads to process.

  For every batch it creates a publisher to process the batch.
  It then makes the supervisor supervise that publisher.

  As an extra complication we only want to process one batch at
  a time/run one publisher at a time. For that we need to make
  the batcher listen to/wait for an :exit/:normal message from
  the publisher (and then create the next batch). 
  """

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
    {:ok, spid} = Supervisor.start_link([], strategy: :one_for_one)
    
    {:ok, {spid, :c.pid(0,0,0)}}
  end

  @impl true
  def handle_cast(:run, state) do
    Process.send_after(self(), :publish, 1_000)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:kill, {_spid, ppid} = state) do
    Process.send_after(ppid, :kill, 0)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:stop, {spid, _ppid} = state) do
    :ok = Supervisor.stop(spid)
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:publish, {spid, _ppid}) do
    # Create the batch to process.
    timestamp = NaiveDateTime.utc_now
    batch = 1..10 |> Enum.map(fn i ->
      "payload - #{i} - #{timestamp}"
    end)

    # Create/Configure the Publisher to start. Note: The :transient
    # restart (means the Publisher will get restarted by the supervisor,
    # if it exists for any other reason than :normal).
    publisher = %{
      id: :publisher,
      start: {AmqpReconnect.Publisher, :start_link, [{batch, self()}]},
      restart: :transient
    }

    # Delete the old/previous publisher/child (if there is one)
    # and then add the new one (with the new batch).
    Supervisor.delete_child(spid, :publisher)
    {:ok, ppid} = Supervisor.start_child(spid, publisher)
    Logger.info("Publisher started (#{inspect(ppid)}) ...")

    {:noreply, {spid, ppid}}
  end

  @impl true
  def handle_info(:next, state) do
    Process.send_after(self(), :publish, 1_000)
    
    {:noreply, state}
  end
end
