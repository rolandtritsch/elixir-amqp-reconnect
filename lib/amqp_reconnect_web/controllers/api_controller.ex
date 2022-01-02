defmodule AmqpReconnectWeb.ApiController do
  use AmqpReconnectWeb, :controller

  def start(conn, _params) do
    {:ok, _} = AmqpReconnect.Publisher.run()
    
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

  def stop(conn, _params) do
    AmqpReconnect.Publisher.stop()
    
    conn
    |> put_status(:ok)
    |> text("publisher stopped")
  end
end
