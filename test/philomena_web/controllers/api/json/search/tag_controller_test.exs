defmodule PhilomenaWeb.Api.Json.Search.TagControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  @moduletag :search

  import Philomena.TagsFixtures

  alias Philomena.Tags.Tag
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers

  setup do
    Search.clear_index!(Tag)
    :ok
  end

  describe "GET /api/v1/json/search/tags" do
    test "finds tags by name", %{conn: conn} do
      tag = tag_fixture(name: "safe")
      _other = tag_fixture(name: "solo")
      SearchHelpers.reindex_all!(Tag)

      conn = get(conn, ~p"/api/v1/json/search/tags?q=safe")

      assert json_response(conn, 200) == %{
               "total" => 1,
               "tags" => [
                 %{
                   "id" => tag.id,
                   "name" => "safe",
                   "slug" => "safe",
                   "description" => "",
                   "short_description" => "",
                   "images" => 0,
                   "spoiler_image_uri" => nil,
                   "namespace" => nil,
                   "name_in_namespace" => "safe",
                   "category" => nil,
                   "aliased_tag" => nil,
                   "aliases" => [],
                   "implied_tags" => [],
                   "implied_by_tags" => [],
                   "dnp_entries" => []
                 }
               ]
             }
    end

    test "matches tags by wildcard and analyzed fields", %{conn: conn} do
      _artist = tag_fixture(name: "artist:hoofbeats")
      _other = tag_fixture(name: "solo")
      SearchHelpers.reindex_all!(Tag)

      conn1 = get(conn, ~p"/api/v1/json/search/tags?q=artist:*")

      assert %{"total" => 1, "tags" => [%{"name" => "artist:hoofbeats"}]} =
               json_response(conn1, 200)

      conn2 = get(conn, ~p"/api/v1/json/search/tags?q=category:origin")

      assert %{"total" => 1, "tags" => [%{"name" => "artist:hoofbeats"}]} =
               json_response(conn2, 200)
    end

    test "returns an empty result for a missing query string", %{conn: conn} do
      _tag = tag_fixture(name: "safe")
      SearchHelpers.reindex_all!(Tag)

      # NOTE: a missing/empty q compiles to match_none, a 200 with no
      # results - not a 400.
      conn = get(conn, ~p"/api/v1/json/search/tags")

      assert json_response(conn, 200) == %{"tags" => [], "total" => 0}
    end

    test "returns 400 with a JSON error for an unparsable query", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/search/tags?q=)")

      assert json_response(conn, 400) == %{"error" => "is invalid: Imbalanced parentheses."}
    end
  end
end
