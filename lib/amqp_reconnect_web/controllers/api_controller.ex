defmodule AmqpReconnectWeb.ApiController do
  use AmqpReconnectWeb, :controller

  def start(conn, _params) do
    AmqpReconnect.Batcher.run()
    
    conn
    |> put_status(:ok)
    |> text("batcher started")
  end

  def kill(conn, _params) do
    AmqpReconnect.Batcher.kill()
    
    conn
    |> put_status(:ok)
    |> text("connection killed")
  end

  def stop(conn, _params) do
    AmqpReconnect.Batcher.stop()
    
    conn
    |> put_status(:ok)
    |> text("batcher stopped")
  end
end
