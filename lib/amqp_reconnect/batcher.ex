defmodule AmqpReconnect.Batcher do
  @moduledoc """
  This batcher is a gen_stage producer. It waits for demand to
  arrive and will then create batches of payloads to process.
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
    {:producer, 0}
  end

  @impl true
  def handle_demand(demand, count) do
    # Create the batch to process.
    timestamp = NaiveDateTime.utc_now
    batch = 1..demand |> Enum.map(fn i ->
      "payload - #{i} - #{timestamp}"
    end)

    {:noreply, batch, count + demand}
  end
end
