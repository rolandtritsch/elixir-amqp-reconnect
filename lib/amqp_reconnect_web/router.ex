defmodule AmqpReconnectWeb.Router do
  use AmqpReconnectWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", AmqpReconnectWeb do
    pipe_through :api

    get "/start", ApiController, :start
    get "/kill", ApiController, :kill
  end
end
