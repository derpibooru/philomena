defmodule Philomena.ConcurrentDataCaseTest do
  use Philomena.ConcurrentDataCase

  import Philomena.TagsFixtures
  alias Philomena.Tags.Tag

  test "workers hold distinct connections and see committed fixtures" do
    tag = tag_fixture()
    barrier = start_supervised!({Agent, fn -> [] end})

    results =
      concurrently(
        for _ <- 1..2 do
          fn ->
            Repo.transaction(fn ->
              %{rows: [[backend]]} = Repo.query!("SELECT pg_backend_pid()")
              assert Repo.get!(Tag, tag.id).name == tag.name

              worker = self()

              workers =
                Agent.get_and_update(barrier, fn workers ->
                  workers = [worker | workers]
                  {workers, workers}
                end)

              if length(workers) == 2, do: Enum.each(workers, &send(&1, :release))
              assert_receive :release, 5_000
              backend
            end)
          end
        end
      )

    assert [{:ok, first}, {:ok, second}] = results
    refute first == second
  end

  test "truncation removes committed rows and preserves migrations" do
    migrations = Repo.query!("SELECT version FROM schema_migrations ORDER BY version").rows
    tag_fixture()
    truncate!()

    assert Repo.aggregate(Tag, :count) == 0

    assert Repo.query!("SELECT version FROM schema_migrations ORDER BY version").rows ==
             migrations
  end
end
