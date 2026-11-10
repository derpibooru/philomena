defmodule PhilomenaQuery.SearchHelpersTest do
  @moduledoc """
  Smoke tests for the OpenSearch strategy: test-prefixed indexes on the
  shared cluster, created once at boot and cleared of documents per test,
  with explicit reindex + refresh.
  """

  use Philomena.DataCase, async: false

  @moduletag :search

  import Philomena.ImagesFixtures

  alias Philomena.Images.Image
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers

  setup do
    Search.clear_index!(Image)
    :ok
  end

  test "indexes are namespaced away from development data" do
    assert Search.index_name(Image) == "test_images"
  end

  test "reindex_all!/1 makes sandboxed fixture rows searchable" do
    image = image_fixture()
    SearchHelpers.reindex_all!(Image)

    results = Search.search(Image, %{query: %{match_all: %{}}})

    assert [hit] = results["hits"]["hits"]
    assert hit["_id"] == to_string(image.id)
  end

  test "multi-search results retain query names" do
    image = image_fixture()
    SearchHelpers.reindex_all!(Image)

    definition = Search.search_definition(Image, %{query: %{match_all: %{}}})

    assert %{documents: raw_result} = Search.msearch(documents: definition)
    assert [%{"_id" => id}] = raw_result["hits"]["hits"]
    assert id == to_string(image.id)

    assert %{records: page} =
             Search.msearch_records(records: {definition, Image})

    assert [%Image{id: id}] = page.entries
    assert id == image.id
  end

  test "Search.clear_index!/1 leaves the index empty" do
    results = Search.search(Image, %{query: %{match_all: %{}}})

    assert [] == results["hits"]["hits"]
  end
end
