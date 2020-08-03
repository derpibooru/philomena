import Config

# ## Using releases (Elixir v1.9+)
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start each relevant endpoint:
#
#     config :philomena, PhilomenaWeb.Endpoint, server: true
#
# Then you can assemble a release by calling `mix release`.
# See `mix help release` for more information.

config :bcrypt_elixir,
  log_rounds: String.to_integer(System.get_env("BCRYPT_ROUNDS") || "12")

config :philomena,
  channel_image_file_root: System.fetch_env!("CHANNEL_IMAGE_FILE_ROOT"),
  channel_banner_file_root: System.fetch_env!("CHANNEL_BANNER_FILE_ROOT"),
  anonymous_name_salt: System.fetch_env!("ANONYMOUS_NAME_SALT"),
  elasticsearch_url: System.get_env("ELASTICSEARCH_URL") || "http://localhost:9200",
  advert_file_root: System.fetch_env!("ADVERT_FILE_ROOT"),
  avatar_file_root: System.fetch_env!("AVATAR_FILE_ROOT"),
  channel_url_root: System.fetch_env!("CHANNEL_URL_ROOT"),
  badge_file_root: System.fetch_env!("BADGE_FILE_ROOT"),
  password_pepper: System.fetch_env!("PASSWORD_PEPPER"),
  avatar_url_root: System.fetch_env!("AVATAR_URL_ROOT"),
  advert_url_root: System.fetch_env!("ADVERT_URL_ROOT"),
  image_file_root: System.fetch_env!("IMAGE_FILE_ROOT"),
  tumblr_api_key: System.fetch_env!("TUMBLR_API_KEY"),
  otp_secret_key: System.fetch_env!("OTP_SECRET_KEY"),
  image_url_root: System.fetch_env!("IMAGE_URL_ROOT"),
  badge_url_root: System.fetch_env!("BADGE_URL_ROOT"),
  mailer_address: System.fetch_env!("MAILER_ADDRESS"),
  tag_file_root: System.fetch_env!("TAG_FILE_ROOT"),
  tag_url_root: System.fetch_env!("TAG_URL_ROOT"),
  redis_host: System.get_env("REDIS_HOST") || "localhost",
  proxy_host: System.get_env("PROXY_HOST"),
  camo_host: System.fetch_env!("CAMO_HOST"),
  camo_key: System.fetch_env!("CAMO_KEY"),
  cdn_host: System.fetch_env!("CDN_HOST")

config :philomena, Philomena.Repo,
  url: System.fetch_env!("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "32")

config :philomena, Philomena.Mailer,
  adapter: Bamboo.SMTPAdapter,
  server: System.fetch_env!("SMTP_RELAY"),
  hostname: System.fetch_env!("SMTP_DOMAIN"),
  port: System.get_env("SMTP_PORT") || 587,
  username: System.fetch_env!("SMTP_USERNAME"),
  password: System.fetch_env!("SMTP_PASSWORD"),
  tls: :always,
  auth: :always

config :philomena, PhilomenaWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: {:system, "PORT"}],
  url: [host: System.fetch_env!("APP_HOSTNAME"), scheme: "https", port: 443],
  secret_key_base: System.fetch_env!("SECRET_KEY_BASE"),
  server: true
