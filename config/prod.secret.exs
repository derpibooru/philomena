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
  password_pepper: System.get_env("PASSWORD_PEPPER"),
  otp_secret_key: System.get_env("OTP_SECRET_KEY"),
  image_url_root: System.get_env("IMAGE_URL_ROOT"),
  camo_host: System.get_env("CAMO_HOST"),
  camo_key: System.get_env("CAMO_KEY"),
  cdn_host: System.get_env("CDN_HOST")

config :philomena, Philomena.Repo,
  # ssl: true,
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

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
