defmodule Philomena.ConcurrentDataCase do
  @moduledoc """
  Test case and helpers for tests that deliberately run database operations in
  parallel.

  Concurrent tests commit writes through independent pool checkouts. They run
  synchronously and truncate all application tables, resetting identity sequences,
  after each test.
  """

  use ExUnit.CaseTemplate

  @skip_tables ~w(schema_migrations)

  using do
    quote do
      use ExUnit.Case, async: false
      alias Philomena.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Philomena.DataCase
      import Philomena.ConcurrentDataCase
    end
  end

  alias Ecto.Adapters.SQL.Sandbox
  alias Philomena.Repo

  setup do
    Sandbox.mode(Repo, :auto)

    on_exit(fn ->
      try do
        truncate!()
      after
        Sandbox.mode(Repo, :manual)
      end
    end)

    :ok
  end

  @doc """
  Removes committed test data.
  """
  def truncate! do
    %{rows: [tables]} =
      Repo.query!(
        """
        SELECT string_agg(format('%I.%I', schemaname, tablename), ', ') FROM pg_tables
        WHERE schemaname = 'public'
        AND tablename <> ALL($1)
        """,
        [@skip_tables]
      )

    Repo.query!("TRUNCATE #{tables} CASCADE")

    :ok
  end

  @doc """
  Runs zero-argument functions concurrently, releasing all workers together.

  Workers use independent database checkouts. All workers are stopped before
  returning, including when a worker fails or times out, so cleanup cannot race
  with outstanding writes.

  Can only be used from a test process, not from a worker or `setup_all`.
  Results are returned in input order.
  """
  def concurrently(functions, timeout \\ 10_000) when is_list(functions) do
    supervisor = start_supervised!(Task.Supervisor, id: ConcurrentDataCaseSupervisor)

    tasks =
      Enum.map(functions, fn function ->
        Task.Supervisor.async_nolink(supervisor, fn ->
          receive do
            :go -> function.()
          end
        end)
      end)

    try do
      tasks
      |> Enum.shuffle()
      |> Enum.each(&send(&1.pid, :go))

      Enum.map(tasks, &Task.await(&1, timeout))
    after
      Enum.each(tasks, &Task.shutdown(&1, :brutal_kill))
      stop_supervised!(ConcurrentDataCaseSupervisor)
    end
  end
end
