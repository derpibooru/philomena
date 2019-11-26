# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :philomena,
  ecto_repos: [Philomena.Repo],
  elasticsearch_url: "http://localhost:9200",
  password_pepper: "dn2e0EpZrvBLoxUM3gfQveBhjf0bG/6/bYhrOyq3L3hV9hdo/bimJ+irbDWsuXLP",
  otp_secret_key: "Wn7O/8DD+qxL0X4X7bvT90wOkVGcA90bIHww4twR03Ci//zq7PnMw8ypqyyT/b/C",
  image_url_root: "/img",
  avatar_url_root: "/avatars",
  badge_url_root: "/media",
  image_file_root: "priv/static/system/images"

config :philomena, :pow,
  user: Philomena.Users.User,
  repo: Philomena.Repo,
  web_module: PhilomenaWeb,
  users_context: Philomena.Users,
  extensions: [PowResetPassword, PowLockout, PowCaptcha, PowPersistentSession],
  controller_callbacks: Pow.Extension.Phoenix.ControllerCallbacks,
  mailer_backend: PhilomenaWeb.PowMailer,
  captcha_verifier: Philomena.Captcha,
  cache_store_backend: Pow.Store.Backend.MnesiaCache

config :bcrypt_elixir,
  log_rounds: 12

config :elastix,
  json_codec: Jason

config :canary,
  repo: Philomena.Repo

# Configures the endpoint
config :philomena, PhilomenaWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "xZYTon09JNRrj8snd7KL31wya4x71jmo5aaSSRmw1dGjWLRmEwWMTccwxgsGFGjM",
  render_errors: [view: PhilomenaWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Philomena.PubSub, adapter: Phoenix.PubSub.PG2]

config :philomena, :generators, migration: false

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
config :bamboo, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
