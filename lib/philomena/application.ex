defmodule Philomena.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    configure_logging()

    # List all child processes to be supervised
    children = [
      # Start the Ecto repository
      Philomena.Repo,

      # Background queueing system
      Philomena.ExqSupervisor,

      # Mailer
      {Task.Supervisor, name: Philomena.AsyncEmailSupervisor},

      # Starts a worker by calling: Philomena.Worker.start_link(arg)
      # {Philomena.Worker, arg},
      {Redix, name: :redix, host: Application.get_env(:philomena, :redis_host)},
      {Phoenix.PubSub,
       [
         name: Philomena.PubSub,
         adapter: Phoenix.PubSub.Redis,
         host: Application.get_env(:philomena, :redis_host),
         node_name: valid_node_name(node())
       ]},

      # Advert update batching
      Philomena.Adverts.Server,

      # Start the endpoint when the application starts
      PhilomenaWeb.UserFingerprintUpdater,
      PhilomenaWeb.UserIpUpdater,
      PhilomenaWeb.Endpoint
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

  # Redis adapter really really wants you to have a unique node name,
  # so just fake one if iex is being started
  defp valid_node_name(node) when node in [nil, :nonode@nohost],
    do: Base.encode16(:crypto.strong_rand_bytes(6))

  defp valid_node_name(node), do: node

  defp configure_logging() do
    # Log filtering design is borrowed from the Rust's `tracing` observability framework.
    # Specifically from the `EnvFilter` syntax:
    # https://docs.rs/tracing-subscriber/latest/tracing_subscriber/filter/struct.EnvFilter.html
    # However, it implements a simpler subset of that syntax which is just prefix matching.
    #
    # It would also be cool to get tracing's spans model for better low-level and
    # concurrent logs context. But spans implementation would require a lot of work,
    # unless there is an existing library for that. Anyway, for now, this should suffice.
    filters =
      System.get_env("PHILOMENA_LOG", "")
      |> String.split(",")
      |> Enum.map(&String.trim(&1))
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn directive ->
        {selector, level} =
          case String.split(directive, "=", parts: 2) do
            [selector, level] -> {selector, level}
            [level] -> {nil, level}
          end

        {selector, String.to_existing_atom(level)}
      end)

    if not Enum.empty?(filters) do
      allow_log_event? = fn event ->
        with {module, function, _arity} <- Map.get(event.meta, :mfa),
             scope <- "#{inspect(module)}.#{function}",
             {_selector, level} when not is_nil(filters) <-
               filters
               |> Enum.find(fn {selector, _level} ->
                 is_nil(selector) or String.starts_with?(scope, selector)
               end) do
          Logger.compare_levels(event.level, level) != :lt
        else
          _ -> false
        end
      end

      :logger.add_primary_filter(
        :sql_logs,
        {fn event, _ -> if(allow_log_event?.(event), do: :ignore, else: :stop) end, []}
      )
    end
  end
end
