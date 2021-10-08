defmodule AmqpReconnectWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :amqp_reconnect

  plug AmqpReconnectWeb.Router
end
