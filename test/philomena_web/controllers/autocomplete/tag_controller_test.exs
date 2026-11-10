defmodule PhilomenaWeb.Autocomplete.TagControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  # The action prefix-searches the OpenSearch tag index, so it follows the
  # search recipe (recreate index in setup, reindex after fixtures). It has
  # two shapes: v1 (default, "?vsn" absent) returns a bare list of
  # label/value maps; v2 ("?vsn=2") returns a {suggestions|error} object and
  # validates its params. Both filter out tags with no images.

  @moduletag :search

  import Philomena.TagsFixtures

  alias Philomena.Tags.Tag
  alias Philomena.Repo
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers

  setup do
    Search.clear_index!(Tag)
    :ok
  end

  defp tag_with_images(name, images_count) do
    tag = tag_fixture(name: name)

    tag
    |> Ecto.Changeset.change(images_count: images_count)
    |> Repo.update!()
  end

  describe "GET /autocomplete/tags (v1, default)" do
    test "returns label/value suggestions for a matching prefix", %{conn: conn} do
      _safe = tag_with_images("safe", 42)
      _other = tag_with_images("solo", 7)
      SearchHelpers.reindex_all!(Tag)

      conn = get(conn, ~p"/autocomplete/tags?term=saf")

      assert json_response(conn, 200) == [%{"label" => "safe (42)", "value" => "safe"}]
    end

    test "excludes tags that have no images", %{conn: conn} do
      _zero = tag_with_images("safe", 0)
      SearchHelpers.reindex_all!(Tag)

      conn = get(conn, ~p"/autocomplete/tags?term=saf")

      assert json_response(conn, 200) == []
    end

    test "returns an empty list for a too-short term", %{conn: conn} do
      _safe = tag_with_images("safe", 42)
      SearchHelpers.reindex_all!(Tag)

      # NOTE: v1 swallows the "term too short" error into an empty list (200),
      # unlike v2 which reports it as a 422.
      conn = get(conn, ~p"/autocomplete/tags?term=sa")

      assert json_response(conn, 200) == []
    end

    test "returns an empty list when the term is missing", %{conn: conn} do
      conn = get(conn, ~p"/autocomplete/tags")

      assert json_response(conn, 200) == []
    end

    test "is reachable by logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      _safe = tag_with_images("safe", 42)
      SearchHelpers.reindex_all!(Tag)

      conn = get(conn, ~p"/autocomplete/tags?term=saf")

      assert json_response(conn, 200) == [%{"label" => "safe (42)", "value" => "safe"}]
    end
  end

  describe "GET /autocomplete/tags (v2)" do
    test "returns structured suggestions for a matching prefix", %{conn: conn} do
      _safe = tag_with_images("safe", 42)
      SearchHelpers.reindex_all!(Tag)

      conn = get(conn, ~p"/autocomplete/tags?vsn=2&term=saf")

      assert json_response(conn, 200) == %{
               "suggestions" => [
                 %{"alias" => nil, "canonical" => "safe", "images" => 42}
               ]
             }
    end

    test "excludes tags that have no images", %{conn: conn} do
      _zero = tag_with_images("safe", 0)
      SearchHelpers.reindex_all!(Tag)

      conn = get(conn, ~p"/autocomplete/tags?vsn=2&term=saf")

      assert json_response(conn, 200) == %{"suggestions" => []}
    end

    test "respects the limit parameter", %{conn: conn} do
      _a = tag_with_images("safeaa", 40)
      _b = tag_with_images("safebb", 30)
      _c = tag_with_images("safecc", 20)
      SearchHelpers.reindex_all!(Tag)

      conn = get(conn, ~p"/autocomplete/tags?vsn=2&term=safe&limit=2")

      assert %{"suggestions" => suggestions} = json_response(conn, 200)
      assert length(suggestions) == 2
    end

    test "returns a 422 for a too-short term", %{conn: conn} do
      conn = get(conn, ~p"/autocomplete/tags?vsn=2&term=sa")

      assert json_response(conn, 422) == %{
               "error" => "Term is too short, must be at least 3 characters"
             }
    end

    test "returns a 422 when the term is missing", %{conn: conn} do
      conn = get(conn, ~p"/autocomplete/tags?vsn=2")

      assert json_response(conn, 422) == %{"error" => "Term is missing"}
    end

    test "returns a 422 for an out-of-range limit", %{conn: conn} do
      conn = get(conn, ~p"/autocomplete/tags?vsn=2&term=saf&limit=999")

      assert json_response(conn, 422) == %{
               "error" => "Limit must be an integer between 1 and 10"
             }
    end

    test "is reachable by logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      _safe = tag_with_images("safe", 42)
      SearchHelpers.reindex_all!(Tag)

      conn = get(conn, ~p"/autocomplete/tags?vsn=2&term=saf")

      assert %{"suggestions" => [%{"canonical" => "safe"}]} = json_response(conn, 200)
    end
  end
end
