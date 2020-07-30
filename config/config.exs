# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# config :philomena,
#   ecto_repos: [Philomena.Repo],
#   elasticsearch_url: System.get_env("ELASTICSEARCH_HOST"),
#   redis_host: System.get_env("REDIS_HOST"),
#   app_env: System.get_env("MIX_ENV"),
#   password_pepper: "dn2e0EpZrvBLoxUM3gfQveBhjf0bG/6/bYhrOyq3L3hV9hdo/bimJ+irbDWsuXLP",
#   otp_secret_key: "Wn7O/8DD+qxL0X4X7bvT90wOkVGcA90bIHww4twR03Ci//zq7PnMw8ypqyyT/b/C",
#   tumblr_api_key: "fuiKNFp9vQFvjLNvx4sUwti4Yb5yGutBN4Xh10LXZhhRKjWlV4",
#   image_url_root: "/img",
#   avatar_url_root: "/avatars",
#   advert_url_root: "/spns",
#   badge_url_root: "/media",
#   tag_url_root: "/media",
#   channel_url_root: "/media",
#   image_file_root: "priv/static/system/images",
#   advert_file_root: "priv/static/system/images/adverts",
#   avatar_file_root: "priv/static/system/images/avatars",
#   badge_file_root: "priv/static/system/images",
#   channel_image_file_root: "priv/static/system/images",
#   channel_banner_file_root: "priv/static/system/images",
#   tag_file_root: "priv/static/system/images",
#   cdn_host: "",
#   proxy_host: nil,
#   app_dir: File.cwd!()

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

 config :exq,
   queues: [{"videos", 2}, {"images", 4}, {"indexing", 16}],
   scheduler_enable: true,
   max_retries: 1,
   start_on_application: false,
   host: {:system, "REDIS_HOST", "redis"},
   port: {:system, "REDIS_PORT", "6379"}

# config :bcrypt_elixir,
#   log_rounds: 12

config :elastix,
  json_codec: Jason

config :canary,
  repo: Philomena.Repo,
  unauthorized_handler: {PhilomenaWeb.NotAuthorizedPlug, :call},
  not_found_handler: {PhilomenaWeb.NotFoundPlug, :call}

# Configures the endpoint
# config :philomena, PhilomenaWeb.Endpoint,
#   url: [host: "localhost"],
#   secret_key_base: "xZYTon09JNRrj8snd7KL31wya4x71jmo5aaSSRmw1dGjWLRmEwWMTccwxgsGFGjM",
#   render_errors: [view: PhilomenaWeb.ErrorView, accepts: ~w(html json)],
#   pubsub_server: Philomena.PubSub

config :phoenix, :template_engines,
  slim: PhoenixSlime.Engine,
  slime: PhoenixSlime.Engine,
  # If you want to use LiveView
  slimleex: PhoenixSlime.LiveViewEngine

config :tesla, adapter: Tesla.Adapter.Mint

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id],
  truncate: :infinity,
  level: :debug

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason
config :bamboo, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
# import_config "#{Mix.env()}.exs"
