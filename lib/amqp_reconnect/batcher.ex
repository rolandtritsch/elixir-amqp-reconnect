defmodule AmqpReconnect.Batcher do
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
    {:noreply, state}
  end

  @impl true
  def handle_info(:publish, {spid, _ppid}) do
    timestamp = NaiveDateTime.utc_now
    batch = 1..10 |> Enum.map(fn i ->
      "payload - #{i} - #{timestamp}"
    end)

    publisher = %{
      id: Publisher,
      start: {AmqpReconnect.Publisher, :start_link, [batch]},
      restart: :transient
    }

    Supervisor.delete_child(spid, Publisher)
    {:ok, ppid} = Supervisor.start_child(spid, publisher)
    Logger.info("Publisher started (#{inspect(ppid)}) ...")
          
    Process.link(ppid)
    {:noreply, {spid, ppid}}
  end

  @impl true
  def handle_info({:EXIT, pid, :normal}, {_spid, ppid} = state) do
    Logger.info("Normal exit detected (#{inspect(pid)}/#{inspect(ppid)}) ...")
    if pid == ppid, do: Process.send_after(self(), :publish, 1_000)
    {:noreply, state}    
  end

  @impl true
  def handle_info({:EXIT, pid, {:noproc, _}}, {spid, ppid}) do
    Logger.info("Noproc exit detected (#{inspect(pid)}/#{inspect(ppid)}) ...")
    ppid = if pid == ppid do
      Process.sleep(1_000) # give the restarting publisher a second to come up
      [{Publisher, ppid, :worker, [AmqpReconnect.Publisher]}] = Supervisor.which_children(spid)
      Process.unlink(pid)
      Process.link(ppid)
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
