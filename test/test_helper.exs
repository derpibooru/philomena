ExUnit.start()

# Stop batching servers for the duration of the test run. They periodically wake
# and flush whatever updates have been cast to them. An empty flush is free, but
# as soon as a controller test runs then the servers will receive data and issue
# real writes - from a process that owns no sandbox connection, so with the
# sandbox in :manual mode it raises DBConnection.OwnershipError. Terminating the
# child avoids the periodic noise. GenServer.cast to the now-dead name still
# returns :ok silently, so casts during tests are harmlessly dropped.
Supervisor.terminate_child(Philomena.Supervisor, Philomena.Adverts.Server)
Supervisor.terminate_child(Philomena.Supervisor, Philomena.UserIps.Server)
Supervisor.terminate_child(Philomena.Supervisor, Philomena.UserFingerprints.Server)

# Use Exq's in-memory fake queue in tests. This keeps enqueue side effects
# observable to tests without writing jobs to the shared Valkey instance.
{:ok, _exq_mock} = Exq.Mock.start_link(mode: :fake)

# Create every searchable index once, with the current mappings. Tests get
# per-test isolation from PhilomenaQuery.Search.clear_index!/1, which only
# deletes documents - dropping and recreating an index costs ~95 ms and used to
# run once per test.
PhilomenaQuery.SearchHelpers.create_all_indexes!()

Ecto.Adapters.SQL.Sandbox.mode(Philomena.Repo, :manual)
