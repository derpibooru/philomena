defmodule Philomena.SearchMigratorTest do
  use Philomena.DataCase, async: false

  @moduletag :search

  import Philomena.TagsFixtures

  alias Philomena.SearchMigrator
  alias Philomena.SearchPolicy
  alias Philomena.Tags.Tag
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.Search.Api
  alias PhilomenaQuery.Search.WriteTargets
  alias PhilomenaQuery.SearchHelpers

  @migrate_opts [maintenance: false, settle_ms: 0]

  setup do
    :ok = Search.delete_index!(Tag)
    WriteTargets.refresh()

    on_exit(fn ->
      # Restore a normal empty index for subsequent suites. HTTP only - the
      # sandbox connection is gone by the time this runs.
      :ok = Search.delete_index!(Tag)
      :ok = Search.create_index!(Tag)
      WriteTargets.refresh()
    end)
  end

  test "creates a fresh versioned index behind the alias" do
    migrate!()

    assert %{
             status: :aliased,
             live_physical: "test_tags_v1",
             live_version: 1,
             orphans: []
           } = live()

    assert Search.search(Tag, %{query: %{match_all: %{}}})["hits"]["hits"] == []
  end

  test "an additive version bump updates the mapping in place" do
    migrate!()

    additive =
      put_in(mapping(), [:mappings, :properties, :migrator_test_field], %{type: "keyword"})

    migrate!(version: 2, mapping: additive)

    state = live()
    assert state.live_physical == "test_tags_v1"
    assert state.live_version == 2

    assert get_in(state.live_mapping, ["properties", "migrator_test_field", "type"]) ==
             "keyword"
  end

  test "a rebuild bump reindexes into a new physical index and swaps the alias" do
    migrate!()
    tag = tag_fixture()
    SearchHelpers.reindex_all!(Tag)

    migrate!(version: 2, mapping: changed_mapping())

    state = live()
    assert state.live_physical == "test_tags_v2"
    assert state.live_version == 2
    assert state.orphans == []

    Search.refresh_index!(Tag)
    assert [hit] = Search.search(Tag, %{query: %{match_all: %{}}})["hits"]["hits"]
    assert hit["_id"] == to_string(tag.id)
    assert hit["_index"] == "test_tags_v2"
  end

  test "a bare legacy index is destructively recreated" do
    {:ok, %{status: 200}} = Api.create_index(url(), "test_tags", mapping())
    tag = tag_fixture()

    migrate!()

    state = live()
    assert state.status == :aliased
    assert state.live_physical == "test_tags_v1"
    assert state.orphans == []

    Search.refresh_index!(Tag)
    assert [hit] = Search.search(Tag, %{query: %{match_all: %{}}})["hits"]["hits"]
    assert hit["_id"] == to_string(tag.id)
  end

  test "a stale crashed migration target is deleted and rebuilt" do
    migrate!()

    stale_start = DateTime.add(DateTime.utc_now(), -24 * 3600, :second)

    :ok =
      Search.create_index!(Tag,
        version: 2,
        alias: false,
        meta: %{migration_started_at: stale_start}
      )

    migrate!(version: 2, mapping: changed_mapping())

    state = live()
    assert state.live_physical == "test_tags_v2"
    assert state.live_version == 2
    assert state.orphans == []
  end

  test "a fresh migration target aborts the run unless forced" do
    migrate!()

    :ok =
      Search.create_index!(Tag,
        version: 2,
        alias: false,
        meta: %{migration_started_at: DateTime.utc_now()}
      )

    assert_raise RuntimeError, ~r/another migration run may be active/, fn ->
      migrate!(version: 2, mapping: changed_mapping())
    end

    migrate!(version: 2, mapping: changed_mapping(), force: true)

    assert %{live_physical: "test_tags_v2", live_version: 2} = live()
  end

  test "re-running at the current version is a noop" do
    migrate!()

    assert SearchMigrator.plan_action(live(), 1, mapping()) == :noop
  end

  test "plan_action distinguishes additive bumps, rebuilds, and warnings" do
    migrate!()
    state = live()

    additive =
      put_in(mapping(), [:mappings, :properties, :migrator_test_field], %{type: "keyword"})

    assert SearchMigrator.plan_action(state, 2, additive) == :update_mapping
    assert SearchMigrator.plan_action(state, 2, changed_mapping()) == :rebuild

    # changed mapping without a version bump
    assert {:warn, _} = SearchMigrator.plan_action(state, 1, changed_mapping())

    # live version ahead of the code (rollback)
    live_ahead = %{state | live_version: 5}
    assert {:warn, _} = SearchMigrator.plan_action(live_ahead, 1, mapping())
  end

  test "plan_action on missing and legacy states" do
    missing = %{status: :missing, alias: "test_tags", orphans: []}
    assert SearchMigrator.plan_action(missing, 1, mapping()) == :create

    orphaned = %{missing | orphans: ["test_tags_v1"]}
    assert SearchMigrator.plan_action(orphaned, 1, mapping()) == {:attach_orphan, "test_tags_v1"}

    legacy = %{status: :legacy, alias: "test_tags", orphans: []}
    assert SearchMigrator.plan_action(legacy, 1, mapping()) == :recreate
  end

  defp migrate!(opts \\ []) do
    :ok = SearchMigrator.migrate_schema(Tag, @migrate_opts ++ opts)
  end

  defp live, do: Search.live_state(Tag)

  defp mapping, do: SearchPolicy.index_for(Tag).mapping()

  # A non-additive change: an existing property's analyzer differs
  defp changed_mapping do
    put_in(
      mapping(),
      [:mappings, :properties, :description],
      %{type: "text", analyzer: "simple"}
    )
  end

  defp url, do: SearchPolicy.opensearch_url()
end
