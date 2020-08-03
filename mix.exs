defmodule Philomena.MixProject do
  use Mix.Project

  def project do
    [
      app: :philomena,
      version: "0.1.0",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Philomena.Application, []},
      extra_applications: [:logger, :canada, :mnesia, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.5"},
      {:phoenix_pubsub, "~> 2.0"},
      {:phoenix_ecto, "~> 4.1"},
      {:ecto_sql, "~> 3.4"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 2.14"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:gettext, "~> 0.17"},
      {:jason, "~> 1.1"},
      {:plug_cowboy, "~> 2.3"},
      {:phoenix_slime, "~> 0.13"},
      {:ecto_network, "~> 1.3"},
      {:pow, "~> 1.0"},
      {:bcrypt_elixir, "~> 2.2"},
      {:pot, "~> 0.11"},
      {:secure_compare, "~> 0.1.0"},
      {:elastix, "~> 0.8.0"},
      {:nimble_parsec, "~> 0.5.3"},
      {:canary, "~> 1.1.1"},
      {:scrivener_ecto, "~> 2.3"},
      {:pbkdf2, "~> 2.0"},
      {:qrcode, "~> 0.1.5"},
      {:redix, "~> 0.10"},
      {:bamboo, "~> 1.4"},
      {:bamboo_smtp, "~> 2.1"},
      {:remote_ip, "~> 0.2"},
      {:briefly, "~> 0.3.0"},
      {:phoenix_mtm, "~> 1.0.0"},
      {:yaml_elixir, "~> 2.4.0"},
      {:distillery, "~> 2.1"},
      {:ranch_connection_drainer, "~> 0.1"},
      {:tesla, "~> 1.3"},
      {:castore, "~> 0.1"},
      {:mint, "~> 1.1"},
      {:libcluster, "~> 3.2"},
      {:exq, "~> 0.13"},
      {:vapor, "~> 0.8.0"},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.load", "run priv/repo/seeds.exs"],
      "ecto.setup_dev": [
        "ecto.create",
        "ecto.load",
        "run priv/repo/seeds.exs",
        "run priv/repo/seeds_development.exs"
      ],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "ecto.migrate": ["ecto.migrate", "ecto.dump"],
      "ecto.rollback": ["ecto.rollback", "ecto.dump"],
      test: ["ecto.create --quiet", "ecto.load", "test"]
    ]
  end
end
