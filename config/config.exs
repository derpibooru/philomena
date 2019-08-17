# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :philomena,
  ecto_repos: [Philomena.Repo]

config :philomena,
  password_pepper: "dn2e0EpZrvBLoxUM3gfQveBhjf0bG/6/bYhrOyq3L3hV9hdo/bimJ+irbDWsuXLP"

config :philomena, :pow,
  user: Philomena.Users.User,
  repo: Philomena.Repo,
  extensions: [PhilomenaWeb.HaltTotp],
  controller_callbacks: Pow.Extension.Phoenix.ControllerCallbacks

config :bcrypt_elixir,
  log_rounds: 12

# Configures the endpoint
config :philomena, PhilomenaWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "xZYTon09JNRrj8snd7KL31wya4x71jmo5aaSSRmw1dGjWLRmEwWMTccwxgsGFGjM",
  render_errors: [view: PhilomenaWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Philomena.PubSub, adapter: Phoenix.PubSub.PG2]

config :phoenix, :template_engines,
  slim: PhoenixSlime.Engine,
  slime: PhoenixSlime.Engine,
  # If you want to use LiveView
  slimleex: PhoenixSlime.LiveViewEngine

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
