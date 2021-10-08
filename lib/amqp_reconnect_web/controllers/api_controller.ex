defmodule AmqpReconnectWeb.ApiController do
  use AmqpReconnectWeb, :controller

  def start(conn, _params) do
    AmqpReconnect.Publisher.run()
    
    conn
    |> put_status(:ok)
    |> text("publisher started")
  end

  def kill(conn, _params) do
    AmqpReconnect.Publisher.kill()
    
    conn
    |> put_status(:ok)
    |> text("connection killed")
  end
end
