defmodule Philomena.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do

    load_system_env()
    IO.puts("Loading environment, starting philomena")

    # List all child processes to be supervised
    children = [
      # Connect to cluster nodes
      {Cluster.Supervisor, [[philomena: [strategy: Cluster.Strategy.ErlangHosts]]]},

      # Session storage
      Philomena.MnesiaClusterSupervisor,

      # Start the Ecto repository
      Philomena.Repo,

      # Background queueing system
      Philomena.ExqSupervisor,

      # Starts a worker by calling: Philomena.Worker.start_link(arg)
      # {Philomena.Worker, arg},
      Philomena.Servers.UserLinkUpdater,
      Philomena.Servers.PicartoChannelUpdater,
      Philomena.Servers.PiczelChannelUpdater,
      Philomena.Servers.Config,
      {Redix, name: :redix, host: Application.get_env(:philomena, :redis_host), port: Application.get_env(:philomena, :redis_port)},
      {Phoenix.PubSub, [name: Philomena.PubSub, adapter: Phoenix.PubSub.PG2]},

      # Start the endpoint when the application starts
      PhilomenaWeb.AdvertUpdater,
      PhilomenaWeb.StatsUpdater,
      PhilomenaWeb.UserFingerprintUpdater,
      PhilomenaWeb.UserIpUpdater,
      PhilomenaWeb.Endpoint,

      # Connection drainer for SIGTERM
      {RanchConnectionDrainer, ranch_ref: PhilomenaWeb.Endpoint.HTTP, shutdown: 30_000}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Philomena.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    PhilomenaWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  def load_system_env() do
    bindings = [
      { :dev_mode, "DEV_MODE", default: "false" },
    ]
    dev_mode = Vapor.load!([%Vapor.Provider.Env{bindings: bindings}]).dev_mode
    dev_mode = if dev_mode == "true", do: true, else: false

    bindings = [
      { :elasticsearch_url,          "ELASTICSEARCH_HOST", default: "http://elasticsearch:9200" },
      { :redis_host,                 "REDIS_HOST", default: "redis" },
      { :redis_port,                 "REDIS_PORT", default: 6379, map: &String.to_integer/1 },
      { :app_env,                    "APP_ENV", default: "prod" },
      { :password_pepper,            "PASSWORD_PEPPER" },
      { :otp_secret_key,             "OTP_SECRET_KEY" },
      { :anonymous_name_salt,        "ANONYMOUS_NAME_SALT" },
      { :tumblr_api_key,             "TUMBLR_API_KEY", required: false },

      { :image_url_root,             "IMAGE_URL_ROOT", default: "/img" },
      { :avatar_url_root,            "AVATAR_URL_ROOT", default: "/avatars" },
      { :advert_url_root,            "ADVERT_URL_ROOT", default: "/spns" },
      { :badge_url_root,             "BADGE_URL_ROOT", default: "/media" },
      { :tag_url_root,               "TAG_URL_ROOT", default: "/media" },
      { :channel_url_root,           "CHANNEL_URL_ROOT", default: "/media" },

      { :image_file_root,            "IMAGE_FILE_ROOT", default: "priv/static/system/images" },
      { :advert_file_root,           "ADVERT_FILE_ROOT", default: "priv/static/system/images/adverts" },
      { :avatar_file_root,           "AVATAR_FILE_ROOT", default: "priv/static/system/images/avatars" },
      { :badge_file_root,            "BADGE_FILE_ROOT", default: "priv/static/system/images" },
      { :channel_image_file_root,    "CHANNEL_IMAGE_FILE_ROOT", default: "priv/static/system/images" },
      { :channel_banner_file_root,   "CHANNEL_BANNER_FILE_ROOT", default: "priv/static/system/images" },
      { :tag_file_root,              "TAG_FILE_ROOT", default: "priv/static/system/images" },
      { :cdn_host,                   "CDN_HOST", default: nil, required: false },
      { :camo_host,                  "CAMO_HOST", default: nil, required: false },
      { :camo_key,                   "CAMO_KEY", default: nil, required: false },
      { :proxy_host,                 "PROXY_HOST", default: nil, required: false },
      { :app_dir,                    "APP_DIR", default: "/srv/philomena" }
    ]
    config = Vapor.load!([%Vapor.Provider.Env{bindings: bindings}])
    Application.put_env(:philomena, Philomena, config)
    config
    |> Enum.each(fn {key, value} ->
      if value != nil && value != "" do
        Application.put_env(:philomena, key, value)
      end
    end)
    Application.put_env(:philomena, :ecto_repos, [Philomena.Repo])

    # bindings = [
    #   { :host,       "REDIS_HOST", default: "redis" },
    #   { :port,       "REDIS_PORT", default: 6379, map: &String.to_integer/1 },
    # ]
    # config = Vapor.load!([%Vapor.Provider.Env{bindings: bindings}])
    # Application.put_env(:philomena, Philomena.ExqSupervisor, [
    #   host: config.host,
    #   port: config.port,
    #   queues: [{"videos", 2}, {"images", 4}, {"indexing", 16}],
    #   scheduler_enable: true,
    #   max_retries: 1,
    #   start_on_application: false,
    # ])

    bindings = [
      { :secret_key_base,  "SECRET_KEY_BASE" },
      { :host,             "APP_HOSTNAME" },
      { :port,             "APP_PORT",         default: 4000 },
    ]
    config = Vapor.load!([%Vapor.Provider.Env{bindings: bindings}])
    Application.put_env(:philomena, PhilomenaWeb.Endpoint, [
      url: [host: config.host, port: config.port, scheme: "https"],
      secret_key_base: config.secret_key_base,
      http: [ip: {0, 0, 0, 0}, port: 4000],
      render_errors: [view: PhilomenaWeb.ErrorView, accepts: ~w(html json)],
      pubsub_server: Philomena.PubSub,
      server: true,
      cache_static_manifest: "priv/static/cache_manifest.json",
    ])

    bindings = [
      { :user,     "POSTGRES_USER",        default: "philomena" },
      { :password, "POSTGRES_PASSWORD" },
      { :hostname, "POSTGRES_HOST",        default: "postgres" },
      { :db,       "POSTGRES_DB",          default: "philomena_db" },
      { :port,     "POSTGRES_PORT",        default: 5432, map: &String.to_integer/1 },
      { :pool,     "POSTGRES_POOL",        default: 32, map: &String.to_integer/1 },
    ]
    config = Vapor.load!([%Vapor.Provider.Env{bindings: bindings}])
    Application.put_env(:philomena, Philomena.Repo, [
      database: config.db,
      username: config.user,
      password: config.password,
      hostname: config.hostname,
      port: config.port,
      show_sensitive_data_on_connection_error: true,
      pool_size: config.pool,
    ])

    IO.puts("Dev_Mode: #{dev_mode}")
    bindings = [
      { :server,      "SMTP_RELAY",     default: nil,   required: !dev_mode },
      { :hostname,    "SMTP_DOMAIN",    default: nil,   required: !dev_mode },
      { :port,        "SMTP_PORT",      default: 587,   required: false },
      { :username,    "SMTP_USERNAME",  default: nil,   required: !dev_mode },
      { :password,    "SMTP_PASSWORD",  default: nil,   required: !dev_mode },
    ]
    config = Vapor.load!([%Vapor.Provider.Env{bindings: bindings}])
    if !dev_mode do
        Application.put_env(:philomena, PhilomenaWeb.Mailer, [
          adapter: Bamboo.SMTPAdapter,
          server: config.server,
          hostname: config.hostname,
          port: config.port,
          username: config.username,
          password: config.password,
          tls: :always,
          auth: :always
        ])
      else
        IO.puts("Starting local SMTP Adapter")
        Application.put_env(:philomena, PhilomenaWeb.Mailer, [
          adapter: Bamboo.LocalAdapter
        ])
      end

    bindings = [
      { :log_rounds,    "BCRYPT_ROUDNS",  default: 12,  map: &String.to_integer/1 },
    ]
    config = Vapor.load!([%Vapor.Provider.Env{bindings: bindings}])
    Application.put_env(:bcrypt_elixir, :log_rounds, config.log_rounds)

  end
end
