defmodule AmqpReconnect.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      AmqpReconnectWeb.Endpoint,
      {AmqpReconnect.Batcher, 0},
      {AmqpReconnect.Publisher, []}
    ]

    opts = [strategy: :one_for_one, name: AmqpReconnect.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
