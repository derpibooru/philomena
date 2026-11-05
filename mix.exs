defmodule Philomena.MixProject do
  use Mix.Project

  def project do
    [
      app: :philomena,
      version: "1.3.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: [
        list_unused_filters: true,
        ignore_warnings: ".dialyzer_ignore.exs",
        plt_add_apps: [:ex_unit, :mix]
      ],
      docs: [formatters: ["html"]],
      listeners: [Phoenix.CodeReloader]
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
      {:phoenix, "~> 1.8"},
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix_ecto, "~> 4.6"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      # Must be kept at 3.x because of Slime
      {:phoenix_html, "~> 3.3"},
      {:phoenix_view, "~> 2.0"},
      {:phoenix_live_reload, "~> 1.6", only: :dev},
      {:gettext, "~> 1.0"},
      {:bandit, "~> 1.8"},
      {:slime, "~> 1.3.1"},
      {:phoenix_slime, "~> 0.13",
       github: "slime-lang/phoenix_slime", ref: "ae3b6db721e373f69eab131ad013edf3264b7d09"},
      {:phoenix_pubsub_redis, "~> 3.0"},
      {:ecto_network, "~> 1.6"},
      {:bcrypt_elixir, "~> 3.3"},
      {:pot, "~> 1.0"},
      {:secure_compare, "~> 0.1"},
      {:nimble_parsec, "~> 1.4"},
      {:scrivener_ecto,
       github: "krns/scrivener_ecto", ref: "eaad1ddd86a9c8ffa422479417221265a0673777"},
      {:pbkdf2, ">= 0.0.0",
       github: "basho/erlang-pbkdf2", ref: "7e9bd5fcd3cc3062159e4c9214bb628aa6feb5ca"},
      {:qrcode, "~> 0.1"},
      {:redix, "~> 1.5"},
      {:remote_ip, "~> 1.2"},
      {:briefly, "~> 0.5"},
      {:req, "~> 0.7.4"},
      {:exq, "~> 0.21"},
      # nimble_options 1.2 rejects the `password: nil` that Exq always passes
      # to Redix when Redis has no password. Hold 1.1 until Exq/Redix handle it.
      {:nimble_options, "~> 1.1.1"},
      {:ex_aws, "~> 2.6"},
      {:ex_aws_s3, "~> 2.5"},
      {:sweet_xml, "~> 0.7"},
      {:inet_cidr, "~> 1.0"},

      # SMTP
      {:swoosh, "~> 1.19"},
      {:mua, "~> 0.2"},
      {:mail, "~> 0.5"},

      # Native modules (such as Markdown and Mediaproc)
      {:rustler, "~> 0.37"},

      # Linting
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:credo_envvar, "~> 0.1", only: [:dev, :test], runtime: false},
      {:credo_naming, "~> 2.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.38", only: [:dev], runtime: false},
      {:patch, "~> 0.16", only: [:dev, :test]},

      # Security checks
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: true},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},

      # Static analysis
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},

      # Authorization
      {:canada, "~> 2.0"}
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
