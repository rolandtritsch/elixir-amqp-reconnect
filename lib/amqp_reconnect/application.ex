defmodule AmqpReconnect.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AmqpReconnectWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: AmqpReconnect.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
