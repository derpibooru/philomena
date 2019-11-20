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
      extra_applications: [:logger, :runtime_tools]
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
      {:phoenix, "~> 1.4.9"},
      {:phoenix_pubsub, "~> 1.1"},
      {:phoenix_ecto, "~> 4.0"},
      {:ecto_sql, "~> 3.1"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 2.11"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:phoenix_slime, "~> 0.12.0"},
      {:ecto_network, "~> 1.1"},
      {:pow, github: "danschultzer/pow", ref: "persistent-session-metadata", override: true},
      {:bcrypt_elixir, "~> 2.0"},
      {:pot, "~> 0.10.1"},
      {:secure_compare, "~> 0.1.0"},
      {:elastix, "~> 0.7.1"},
      {:nimble_parsec, "~> 0.5.1"},
      {:canary, "~> 1.1.1"},
      {:scrivener_ecto, "~> 2.0"},
      {:pbkdf2, "~> 2.0"},
      {:qrcode, "~> 0.1.5"},
      {:redix, "~> 0.10.2"},
      {:bamboo, "~> 1.2"},
      {:bamboo_smtp, "~> 1.7"},
      {:remote_ip, "~> 0.2.0"},
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
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
