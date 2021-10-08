import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :amqp_reconnect, AmqpReconnectWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "QkYjSiXtIgsc/rBgxvDL+ksLk1Bo3IQoQVEgb3JMq6bP6uPN4m8PMFEoe8rm4Srr",
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
