defmodule AmqpReconnectWeb.ApiController do
  use AmqpReconnectWeb, :controller

  def start(conn, _params) do
    conn
    |> put_status(:ok)
    |> text("start")
  end

  def kill(conn, _params) do
    conn
    |> put_status(:ok)
    |> text("kill")
  end
end
