import Config

# ## Using releases (Elixir v1.9+)
#
# If you are doing OTP releases, you can assemble a release
# by calling `mix release`.
#
# See `mix help release` for more information.

config :bcrypt_elixir,
  log_rounds: String.to_integer(System.get_env("BCRYPT_ROUNDS", "12"))

config :philomena,
  anonymous_name_salt: System.fetch_env!("ANONYMOUS_NAME_SALT"),
  hcaptcha_secret_key: System.fetch_env!("HCAPTCHA_SECRET_KEY"),
  hcaptcha_site_key: System.fetch_env!("HCAPTCHA_SITE_KEY"),
  opensearch_url: System.get_env("OPENSEARCH_URL", "https://admin:admin@localhost:9200"),
  advert_file_root: System.fetch_env!("ADVERT_FILE_ROOT"),
  avatar_file_root: System.fetch_env!("AVATAR_FILE_ROOT"),
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
  site_domains: System.fetch_env!("SITE_DOMAINS"),
  tag_url_root: System.fetch_env!("TAG_URL_ROOT"),
  redis_host: System.get_env("REDIS_HOST", "localhost"),
  proxy_host: System.get_env("PROXY_HOST"),
  camo_host: System.get_env("CAMO_HOST"),
  camo_key: System.get_env("CAMO_KEY"),
  cdn_host: System.fetch_env!("CDN_HOST")

app_dir = System.get_env("APP_DIR", File.cwd!())

json_config =
  %{
    aggregation: "aggregation.json",
    avatar: "avatar.json",
    footer: "footer.json",
    quick_tag_table: "quick_tag_table.json",
    tag: "tag.json"
  }
  |> Map.new(fn {name, file} ->
    {name, Jason.decode!(File.read!("#{app_dir}/config/#{file}"))}
  end)

config :philomena,
  config: json_config

config :exq,
  host: System.get_env("REDIS_HOST", "localhost"),
  queues: [
    {"videos", 2},
    {"images", 4},
    {"indexing", 12},
    {"notifications", 2}
  ]

if is_nil(System.get_env("START_WORKER")) do
  # Make queueing available but don't process any jobs
  config :exq, queues: []
end

# S3/Object store config
config :philomena, :s3_primary_options,
  region: System.get_env("S3_REGION", "us-east-1"),
  scheme: System.fetch_env!("S3_SCHEME"),
  host: System.fetch_env!("S3_HOST"),
  port: System.fetch_env!("S3_PORT"),
  access_key_id: System.fetch_env!("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.fetch_env!("AWS_SECRET_ACCESS_KEY"),
  http_opts: [timeout: 180_000, recv_timeout: 180_000]

config :philomena, :s3_primary_bucket, System.fetch_env!("S3_BUCKET")

config :philomena, :s3_secondary_options,
  region: System.get_env("ALT_S3_REGION", "us-east-1"),
  scheme: System.get_env("ALT_S3_SCHEME"),
  host: System.get_env("ALT_S3_HOST"),
  port: System.get_env("ALT_S3_PORT"),
  access_key_id: System.get_env("ALT_AWS_ACCESS_KEY_ID"),
  secret_access_key: System.get_env("ALT_AWS_SECRET_ACCESS_KEY"),
  http_opts: [timeout: 180_000, recv_timeout: 180_000]

config :philomena, :s3_secondary_bucket, System.get_env("ALT_S3_BUCKET")

# Don't bail on OpenSearch's self-signed certificate
config :elastix,
  httpoison_options: [ssl: [verify: :verify_none]]

config :ex_aws, :hackney_opts,
  timeout: 180_000,
  recv_timeout: 180_000,
  use_default_pool: false,
  pool: false

config :ex_aws, :retries,
  max_attempts: 20,
  base_backoff_in_ms: 10,
  max_backoff_in_ms: 10_000

if config_env() != :test do
  # Database config
  config :philomena, Philomena.Repo,
    url: System.fetch_env!("DATABASE_URL"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "16")),
    timeout: 60_000,
    ownership_timeout: 60_000
end

if config_env() == :prod do
  # Production mailer config
  config :philomena, Philomena.Mailer,
    adapter: Swoosh.Adapters.Mua,
    relay: System.fetch_env!("SMTP_RELAY"),
    port: String.to_integer(System.get_env("SMTP_PORT", "587")),
    auth: [
      username: System.fetch_env!("SMTP_USERNAME"),
      password: System.fetch_env!("SMTP_PASSWORD")
    ],
    ssl: [middlebox_comp_mode: false]

  # Production endpoint config
  {:ok, ip} = :inet.parse_address(System.get_env("APP_IP", "127.0.0.1") |> String.to_charlist())

  config :philomena, PhilomenaWeb.Endpoint,
    http: [ip: ip, port: System.fetch_env!("PORT")],
    url: [host: System.fetch_env!("APP_HOSTNAME"), scheme: "https", port: 443],
    secret_key_base: System.fetch_env!("SECRET_KEY_BASE"),
    server: not is_nil(System.get_env("START_ENDPOINT"))
else
  # Don't send email in development
  config :philomena, Philomena.Mailer, adapter: Swoosh.Adapters.Local

  # Use this to debug slime templates
  # config :slime, :keep_lines, true
end
