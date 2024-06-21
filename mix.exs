defmodule Philomena.MixProject do
  use Mix.Project

  def project do
    [
      app: :philomena,
      version: "1.1.0",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: [plt_add_apps: [:mix]],
      docs: [formatters: ["html"]]
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
      {:phoenix, "~> 1.7"},
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.9"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_view, "~> 2.0"},
      {:phoenix_live_reload, "~> 1.4", only: :dev},
      {:gettext, "~> 0.22"},
      {:jason, "~> 1.4"},
      {:ranch, "~> 2.1", override: true},
      {:plug_cowboy, "~> 2.6"},
      {:slime, "~> 1.3.1"},
      {:phoenix_slime, "~> 0.13",
       github: "slime-lang/phoenix_slime", ref: "8944de91654d6fcf6bdcc0aed6b8647fe3398241"},
      {:phoenix_pubsub_redis, "~> 3.0"},
      {:ecto_network, "~> 1.3"},
      {:bcrypt_elixir, "~> 3.0"},
      {:pot, "~> 1.0"},
      {:secure_compare, "~> 0.1"},
      {:elastix, "~> 0.10"},
      {:nimble_parsec, "~> 1.2"},
      {:scrivener_ecto, "~> 2.7"},
      {:pbkdf2, ">= 0.0.0",
       github: "basho/erlang-pbkdf2", ref: "7e9bd5fcd3cc3062159e4c9214bb628aa6feb5ca"},
      {:qrcode, "~> 0.1"},
      {:redix, "~> 1.2"},
      {:remote_ip, "~> 1.1"},
      {:briefly, "~> 0.4"},
      {:req, "~> 0.5"},
      {:exq, "~> 0.17"},
      {:ex_aws, "~> 2.0",
       github: "liamwhite/ex_aws", ref: "a340859dd8ac4d63bd7a3948f0994e493e49bda4", override: true},
      {:ex_aws_s3, "~> 2.0"},
      {:sweet_xml, "~> 0.7"},
      {:inet_cidr, "~> 1.0"},

      # SMTP
      {:swoosh, "~> 1.16"},
      {:mua, "~> 0.2.0"},
      {:mail, "~> 0.3.0"},

      # Markdown
      {:rustler, "~> 0.27"},

      # Linting
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:credo_envvar, "~> 0.1", only: [:dev, :test], runtime: false},
      {:credo_naming, "~> 2.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.30", only: [:dev], runtime: false},

      # Security checks
      {:sobelow, "~> 0.11", only: [:dev, :test], runtime: true},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},

      # Static analysis
      {:dialyxir, "~> 1.2", only: :dev, runtime: false},

      # Fixes for Elixir v1.15+
      {:canary, "~> 1.1",
       github: "marcinkoziej/canary", ref: "704debde7a2c0600f78c687807884bf37c45bd79"}
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
