# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :amqp_reconnect,
  ecto_repos: [AmqpReconnect.Repo]

# Configures the endpoint
config :amqp_reconnect, AmqpReconnectWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: AmqpReconnectWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: AmqpReconnect.PubSub,
  live_view: [signing_salt: "sUV09qIK"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
