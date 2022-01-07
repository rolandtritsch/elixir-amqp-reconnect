defmodule AmqpReconnect.Batcher do
  @moduledoc """
  This batcher is a gen_stage producer. It waits for demand to
  arrive and will then create batches of payloads to process.

  Note: To get the at-least-once semantic we want, we need to
  add the ability to resend batches that were not completely
  processed by the publisher. We do this by keeping a copy
  of the current batch around (in the state).
  """

  use GenStage

  require Logger

  # --- public interface

  def start_link(args) do
    GenStage.start_link(__MODULE__, args, name: __MODULE__)
  end

  # --- callbacks 

  @impl true
  def init(_args) do
    {:producer, []}
  end

  # Create the batch to process.
  @impl true
  def handle_demand(demand, []) do
    timestamp = NaiveDateTime.utc_now
    batch = 1..demand |> Enum.map(fn i ->
      "payload - #{i} - #{timestamp}"
    end)

    {:noreply, batch, batch}
  end

  # Batch was not acked. Resend.
  @impl true
  def handle_demand(_demand, batch) do
    {:noreply, batch, batch}
  end

  # Ack the batch. Next handle_demand will send a new batch
  @impl true
  def handle_call(:ack, _from, _batch) do
    {:reply, :ok, [], []}
  end
end
