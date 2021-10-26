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
    Process.flag(:trap_exit, true)
    {:ok, spid} = Supervisor.start_link([], strategy: :one_for_one)
    
    # state is supervisor-pid and publisher-pid. We have no publisher
    # yet. Use (0,0,0) as a dummy.
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
    {:noreply, state}
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
      id: Publisher,
      start: {AmqpReconnect.Publisher, :start_link, [batch]},
      restart: :transient
    }

    # Delete the old/previous publisher/child (if there is one)
    # and then add the new one (with the new batch).
    Supervisor.delete_child(spid, Publisher)
    {:ok, ppid} = Supervisor.start_child(spid, publisher)
    Logger.info("Publisher started (#{inspect(ppid)}) ...")

    # Link the publisher to this process/the bacther, so that we
    # can listen for the exit below.
    Process.link(ppid)
    
    {:noreply, {spid, ppid}}
  end

  @impl true
  def handle_info({:EXIT, pid, :normal}, {_spid, ppid} = state) do
    Logger.info("Normal exit detected (#{inspect(pid)}/#{inspect(ppid)}) ...")

    # Just make sure the exit came from the publisher. If so, create/publish
    # the next batch.
    if pid == ppid, do: Process.send_after(self(), :publish, 1_000)
    
    {:noreply, state}    
  end

  @impl true
  def handle_info({:EXIT, pid, {:noproc, _}}, {spid, ppid}) do
    Logger.info(":exit/:noproc detected (#{inspect(pid)}/#{inspect(ppid)}) ...")

    # Just making sure that it was really the publisher that died ...
    ppid = if pid == ppid do
      # Give the restarting publisher a second to come up ...
      Process.sleep(1_000)

      # Ask the supervisor for the pid of the newly started publisher
      # and link it to this process.
      [{Publisher, ppid, :worker, [AmqpReconnect.Publisher]}] = Supervisor.which_children(spid)
      Process.unlink(pid); Process.link(ppid)
      
      Logger.info("Publisher (#{inspect(ppid)}) got restarted ...")
      ppid
    else
      Logger.info("Something got restarted ...")
      ppid
    end
    {:noreply, {spid, ppid}}    
  end
  
  @impl true
  def handle_info({:EXIT, pid, reason}, state) do
    Logger.info("Unexpected exit detected (#{inspect(pid)}/#{inspect(reason)}) ...")
    {:noreply, state}    
  end
end
