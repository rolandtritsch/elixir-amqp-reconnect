defmodule AmqpReconnectWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :amqp_reconnect

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_amqp_reconnect_key",
    signing_salt: "sVbFf4t3"
  ]

  plug AmqpReconnectWeb.Router
end
