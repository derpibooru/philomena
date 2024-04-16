import Config

# Configure your database
config :philomena, Philomena.Repo,
  hostname: "postgres",
  username: "postgres",
  password: "postgres",
  database: "philomena_test",
  pool: Ecto.Adapters.SQL.Sandbox

config :philomena,
  pwned_passwords: false,
  captcha: false

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :philomena, PhilomenaWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warning
