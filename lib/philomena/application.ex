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
      {Redix, name: :redix, host: Application.get_env(:philomena, :redis_host)},
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
      { :elasticseach_url,           "ELASTICSEARCH_HOST", default: "http://elasticsearch:9200" },
      { :redis_host,                 "REDIS_HOST", default: "redis" },
      { :redis_port,                 "REDIS_PORT", default: "6379", map: &String.to_integer/1 },
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
      { :cdn_host,                   "CDN_HOST", required: false },
      { :camo_host,                  "CAMO_HOST", required: false },
      { :camo_key,                   "CAMO_KEY", required: false },
      { :proxy_host,                 "PROXY_HOST", default: nil, required: false },
      { :app_dir,                    "APP_DIR", default: "/srv/philomena" }
    ]
    config = Vapor.load!([%Vapor.Provider.Env{bindings: bindings}])
    Application.put_env(:philomena, Philomena, config)
    config
    #|> Enum.with_index
    |> Enum.each(fn {key, value} ->
      if value != nil && value != "" do
        Application.put_env(:philomena, key, value)
      end
    end)

    bindings = [
      { :host,       "EXQ_REDIS_HOST", default: "redis" },
      { :port,       "EXQ_REDIS_PORT", default: "6379", map: &String.to_integer/1 },
    ]
    config = Vapor.load!([%Vapor.Provider.Env{bindings: bindings}])
    Application.put_env(:philomena, Philomena.ExqSupervisor, config)

    bindings = [
      { :secret_key_base,  "SECRET_KEY_BASE" },
      { :host,             "APP_HOSTNAME" },
      { :port,             "APP_PORT",         default: "4000", map: &String.to_integer/1 },
    ]
    config = Vapor.load!([%Vapor.Provider.Env{bindings: bindings}])
    Application.put_env(:philomena, PhilomenaWeb.Endpoint, [
      url: [host: config.host, port: config.port],
      secret_key_base: config.secret_key_base,
    ])

    bindings = [
      { :user,     "POSTGRES_USER",        default: "philomena" },
      { :password, "POSTGRES_PASSWORD" },
      { :hostname, "POSTGRES_HOST",        default: "postgres" },
      { :db,       "POSTGRES_DB",          default: "philomena_db" },
      { :port,     "POSTGRES_PORT",        default: "5432", map: &String.to_integer/1 },
    ]
    config = Vapor.load!([%Vapor.Provider.Env{bindings: bindings}])
    Application.put_env(:philomena, Philomena.Repo, [
      database: config.db,
      username: config.user,
      password: config.password,
      hostname: config.hostname,
      port: config.port,
      show_sensitive_data_on_connection_error: true,
    ])

  end
end
