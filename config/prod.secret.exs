# In this file, we load production configuration and secrets
# from environment variables. You can also hardcode secrets,
# although such is generally not recommended and you have to
# remember to add this file to your .gitignore.
import Config

database_url =
  System.get_env("DATABASE_URL") ||
      "pgsql://" 
      <> (System.get_env("PGUSER")||"postgres")
      <> ":"
      <> (System.get_env("PGPASSWORD")||"postgres")
      <> "@"
      <> (System.get_env("PGHOST")||"postgres")
      <> "/"
      <> (System.get_env("PGDB")||"philomena_dev")
      ||
    raise """
    environment variable DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

config :bcrypt_elixir,
  log_rounds: String.to_integer(System.get_env("BCRYPT_ROUNDS") || "12")

config :philomena,
  channel_image_file_root: System.get_env("CHANNEL_IMAGE_FILE_ROOT"),
  channel_banner_file_root: System.get_env("CHANNEL_BANNER_FILE_ROOT"),
  anonymous_name_salt: System.get_env("ANONYMOUS_NAME_SALT"),
  advert_file_root: System.get_env("ADVERT_FILE_ROOT"),
  avatar_file_root: System.get_env("AVATAR_FILE_ROOT"),
  channel_url_root: System.get_env("CHANNEL_URL_ROOT"),
  badge_file_root: System.get_env("BADGE_FILE_ROOT"),
  password_pepper: System.get_env("PASSWORD_PEPPER"),
  avatar_url_root: System.get_env("AVATAR_URL_ROOT"),
  advert_url_root: System.get_env("ADVERT_URL_ROOT"),
  image_file_root: System.get_env("IMAGE_FILE_ROOT"),
  tumblr_api_key: System.get_env("TUMBLR_API_KEY"),
  otp_secret_key: System.get_env("OTP_SECRET_KEY"),
  image_url_root: System.get_env("IMAGE_URL_ROOT"),
  badge_url_root: System.get_env("BADGE_URL_ROOT"),
  mailer_address: System.get_env("MAILER_ADDRESS"),
  tag_file_root: System.get_env("TAG_FILE_ROOT"),
  tag_url_root: System.get_env("TAG_URL_ROOT"),
  proxy_host: System.get_env("PROXY_HOST"),
  camo_host: System.get_env("CAMO_HOST"),
  camo_key: System.get_env("CAMO_KEY"),
  cdn_host: System.get_env("CDN_HOST"),
  redis_host: System.get_env("REDIS_HOST")||"redis",
  elasticsearch_url: System.get_env("ELASTICSEARCH_HOST")||"http://elasticsearch:9200"

config :exq,
  host: System.get_env("REDIS_HOST")||"redis"

config :philomena, Philomena.Repo,
  # ssl: true,
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "32")

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
  http: [ip: {0, 0, 0, 0}, port: 4000],
  url: [host: System.get_env("APP_HOSTNAME"), scheme: "https", port: 443],
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
