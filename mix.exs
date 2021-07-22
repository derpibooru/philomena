defmodule Philomena.MixProject do
  use Mix.Project

  def project do
    [
      app: :philomena,
      version: "1.1.0",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Philomena.Application, []},
      extra_applications: [:logger, :canada, :runtime_tools]
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
      {:phoenix_ecto, "~> 4.2"},
      {:ecto_sql, "~> 3.5"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 2.14"},
      {:phoenix_live_reload, "~> 1.3", only: :dev},
      {:gettext, "~> 0.18"},
      {:jason, "~> 1.2"},
      {:ranch, "~> 1.6", override: true},
      {:plug_cowboy, "~> 2.3"},
      {:phoenix_slime, "~> 0.13"},
      {:phoenix_pubsub_redis, "~> 3.0"},
      {:ecto_network, "~> 1.3"},
      {:bcrypt_elixir, "~> 2.3"},
      {:pot, "~> 1.0"},
      {:secure_compare, "~> 0.1"},
      {:elastix, "~> 0.8"},
      {:nimble_parsec, "~> 1.1"},
      {:canary, "~> 1.1"},
      {:scrivener_ecto, "~> 2.7"},
      {:pbkdf2, "~> 2.0",
       github: "code-time/erlang-pbkdf2", ref: "f8f0012a97f58ade9c70ac93260e4259e4ca4b8d"},
      {:qrcode, "~> 0.1"},
      {:redix, "~> 0.10.0"},
      {:bamboo, "~> 1.6"},
      {:bamboo_smtp, "~> 3.1"},
      {:remote_ip, "~> 0.2"},
      {:briefly, "~> 0.3"},
      {:phoenix_mtm, "~> 1.0"},
      {:tesla, "~> 1.4"},
      {:castore, "~> 0.1"},
      {:mint, "~> 1.2"},
      {:exq, "~> 0.14"},

      # Linting
      {:credo, "~> 1.5", only: [:dev, :test], override: true},
      {:credo_envvar, "~> 0.1", only: [:dev, :test], runtime: false},
      {:credo_naming, "~> 1.0", only: [:dev, :test], runtime: false},

      # Security checks
      {:sobelow, "~> 0.11", only: [:dev, :test], runtime: true},
      {:mix_audit, "~> 0.1", only: [:dev, :test], runtime: false},

      # Static analysis
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
      "ecto.rollback": ["ecto.rollback", "ecto.dump"]
    ]
  end
end
