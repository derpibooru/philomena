defmodule PhilomenaQuery.Search.WriteTargetsTest do
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

  setup do
    :ok = Search.delete_index!(Tag)
    :ok = SearchMigrator.migrate_schema(Tag, maintenance: false)
    WriteTargets.refresh()

    on_exit(fn ->
      # Restore a normal empty index for subsequent suites. HTTP only - the
      # sandbox connection is gone by the time this runs.
      :ok = Search.delete_index!(Tag)
      :ok = Search.create_index!(Tag)
      WriteTargets.refresh()
    end)
  end

  test "group/2 membership: versioned, aliased, and bare indices; no prefix bleed" do
    body = %{
      "test_tags_v1" => %{"aliases" => %{"test_tags" => %{}}},
      "test_tags_v2" => %{"aliases" => %{}},
      "test_tags" => %{"aliases" => %{}},
      "test_tag_changes_v1" => %{"aliases" => %{"test_tag_changes" => %{}}}
    }

    assert WriteTargets.group(body, "test_tags") == %{
             members: ["test_tags", "test_tags_v1", "test_tags_v2"],
             aliased: ["test_tags_v1"]
           }

    # "test_tags*" wildcards would match tag_changes; the group logic must not
    assert WriteTargets.group(body, "test_tag_changes") == %{
             members: ["test_tag_changes_v1"],
             aliased: ["test_tag_changes_v1"]
           }

    assert WriteTargets.group(body, "test_posts") == %{members: [], aliased: []}
  end

  test "a single aliased member resolves to the alias name" do
    assert WriteTargets.targets_for("test_tags") == ["test_tags"]
  end

  test "an unknown alias resolves to itself" do
    assert WriteTargets.targets_for("test_does_not_exist") == ["test_does_not_exist"]
  end

  test "an unaliased migration target is dual-written until it is removed" do
    :ok = Search.create_index!(Tag, version: 2, alias: false)
    WriteTargets.refresh()

    assert WriteTargets.targets_for("test_tags") == ["test_tags_v1", "test_tags_v2"]

    # A document write through the normal path lands in both physical indices
    tag = tag_fixture()
    SearchHelpers.reindex_all!(Tag)

    for index <- ["test_tags_v1", "test_tags_v2"] do
      {:ok, %{status: 200}} = Api.refresh_index(url(), index)
      {:ok, %{status: 200, body: body}} = Api.search(url(), index, %{query: %{match_all: %{}}})

      assert [hit] = body["hits"]["hits"]
      assert hit["_id"] == to_string(tag.id)
    end

    {:ok, %{status: 200}} = Api.delete_index(url(), "test_tags_v2")
    WriteTargets.refresh()

    assert WriteTargets.targets_for("test_tags") == ["test_tags"]
  end

  defp url, do: SearchPolicy.opensearch_url()
end
