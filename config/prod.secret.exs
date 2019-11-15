# In this file, we load production configuration and secrets
# from environment variables. You can also hardcode secrets,
# although such is generally not recommended and you have to
# remember to add this file to your .gitignore.
use Mix.Config

database_url =
  System.get_env("DATABASE_URL") ||
    raise """
    environment variable DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

config :bcrypt_elixir,
  log_rounds: String.to_integer(System.get_env("BCRYPT_ROUNDS") || "12")

config :philomena,
  anonymous_name_salt: System.get_env("ANONYMOUS_NAME_SALT"),
  password_pepper: System.get_env("PASSWORD_PEPPER"),
  avatar_url_root: System.get_env("AVATAR_URL_ROOT"),
  otp_secret_key: System.get_env("OTP_SECRET_KEY"),
  image_url_root: System.get_env("IMAGE_URL_ROOT"),
  badge_url_root: System.get_env("BADGE_URL_ROOT"),
  camo_host: System.get_env("CAMO_HOST"),
  camo_key: System.get_env("CAMO_KEY"),
  cdn_host: System.get_env("CDN_HOST")

config :philomena, Philomena.Repo,
  # ssl: true,
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

config :philomena, PhilomenaWeb.Mailer,
  adapter: Bamboo.SMTPAdapter,
  server: System.get_env("SMTP_RELAY"),
  hostname: System.get_env("SMTP_DOMAIN"),
  port: System.get_env("SMTP_PORT") || 587,
  username: System.get_env("SMTP_USERNAME"),
  password: System.get_env("SMTP_PASSWORD"),
  tls: :always,
  auth: :always

secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

config :philomena, PhilomenaWeb.Endpoint,
  http: [:inet6, port: String.to_integer(System.get_env("PORT") || "4000")],
  secret_key_base: secret_key_base,
  server: true

# ## Using releases (Elixir v1.9+)
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start each relevant endpoint:
#
#     config :philomena, PhilomenaWeb.Endpoint, server: true
#
# Then you can assemble a release by calling `mix release`.
# See `mix help release` for more information.
