import Config

# Configure your database
config :philomena, Philomena.Repo,
  hostname: "postgres",
  username: "postgres",
  password: "postgres",
  database: "philomena_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  # ExUnit runs up to System.schedulers_online() * 2 async tests at once
  # (its max_cases default), each holding a sandbox connection; with the
  # default pool_size of 10 the pool falls behind and sandbox checkouts
  # start timing out (DBConnection.ConnectionError) once enough async
  # tests exist. Size the pool to match, and give checkouts more queue
  # headroom for bcrypt-heavy user fixtures.
  pool_size: System.schedulers_online() * 2,
  queue_target: 200,
  queue_interval: 2000

config :philomena,
  pwned_passwords: false,
  captcha: false

# Keep test enqueues in memory. The application still exercises the same
# enqueue calls, but the test suite cannot fill the shared development Valkey
# instance with jobs that reference the test database.
config :exq,
  queue_adapter: Exq.Adapters.Queue.Mock

# Namespace OpenSearch indexes so test runs cannot touch dev data on the
# shared cluster. Search-backed tests recreate their index in setup; see
# test/CONVENTIONS.md.
config :philomena, :opensearch_index_prefix, "test_"

# Tests are single-node and refresh write targets explicitly with
# `PhilomenaQuery.Search.WriteTargets.refresh/0`, so migrations need no
# settle time and the background poll can stay quiet.
config :philomena,
  search_target_poll_interval_ms: 1_000,
  search_migration_settle_ms: 0

# External call stubbing. The mailer delivers to the test process
# (`Swoosh.TestAssertions.assert_email_sent/1`); ex_aws object storage
# operations succeed without any storage running; PhilomenaProxy.Http
# (scrapers, camo) routes through Req.Test - tests that trigger outbound
# HTTP must `Req.Test.stub(PhilomenaProxy.Http, fun)` or the request raises.
# The mailer and ex_aws defaults set in config/runtime.exs are skipped for
# the test environment so these values win.
config :philomena, Philomena.Mailer, adapter: Swoosh.Adapters.Test

config :ex_aws, http_client: Philomena.ExAwsHttpClientStub

config :philomena, :req_options, plug: {Req.Test, PhilomenaProxy.Http}

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :philomena, PhilomenaWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test recompilation
config :phoenix, :plug_init_mode, :runtime
