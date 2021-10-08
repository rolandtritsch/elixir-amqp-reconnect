defmodule AmqpReconnectWeb.Router do
  use AmqpReconnectWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", AmqpReconnectWeb do
    pipe_through :api
  end
end
