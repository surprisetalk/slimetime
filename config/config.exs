# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :slime_time,
  ecto_repos: [SlimeTime.Repo]

# Configures the endpoint
config :slime_time, SlimeTime.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "5UROPVA6RuLVxBwja+loXil7Zb1L0gd5+9VpPQxhpoeu5il9j98ytJLtPW0UbMxi",
  render_errors: [view: SlimeTime.ErrorView, accepts: ~w(html json)],
  pubsub: [name: SlimeTime.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
