defmodule PhilomenaWeb.Api.Json.Search.FilterControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  @moduletag :search

  import Philomena.FiltersFixtures
  import Philomena.UsersFixtures

  alias Philomena.Filters.Filter
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers

  setup do
    Search.clear_index!(Filter)
    :ok
  end

  defp response_filter_names(conn) do
    %{"filters" => filters} = json_response(conn, 200)
    Enum.map(filters, & &1["name"])
  end

  describe "GET /api/v1/json/search/filters" do
    test "shows anonymous users only public and system filters", %{conn: conn} do
      user = confirmed_user_fixture()
      _public = filter_fixture(user, name: "aaa public", public: true)
      _private = filter_fixture(user, name: "bbb private")
      SearchHelpers.reindex_all!(Filter)

      conn = get(conn, ~p"/api/v1/json/search/filters?q=*")

      # NOTE: ConnCase seeds the "Default" system filter, which every
      # wildcard search matches; results sort by name ascending
      # (case-insensitively).
      assert response_filter_names(conn) == ["aaa public", "Default"]
    end

    test "includes the key user's own private filters", %{conn: conn} do
      user = confirmed_user_fixture()
      other = confirmed_user_fixture()
      _mine = filter_fixture(user, name: "aaa mine")
      _theirs = filter_fixture(other, name: "bbb theirs")
      SearchHelpers.reindex_all!(Filter)

      conn = get(conn, ~p"/api/v1/json/search/filters?q=*&key=#{user.authentication_token}")

      assert response_filter_names(conn) == ["aaa mine", "Default"]
    end

    test "finds filters by name", %{conn: conn} do
      user = confirmed_user_fixture()
      _public = filter_fixture(user, name: "chartreuse curation", public: true)
      SearchHelpers.reindex_all!(Filter)

      conn = get(conn, ~p"/api/v1/json/search/filters?q=chartreuse+curation")

      assert %{"total" => 1, "filters" => [%{"name" => "chartreuse curation"}]} =
               json_response(conn, 200)
    end

    test "returns an empty result for a missing query string", %{conn: conn} do
      SearchHelpers.reindex_all!(Filter)

      # NOTE: a missing/empty q compiles to match_none, a 200 with no
      # results - not a 400.
      conn = get(conn, ~p"/api/v1/json/search/filters")

      assert json_response(conn, 200) == %{"filters" => [], "total" => 0}
    end

    test "returns 400 with a JSON error for an unparsable query", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/search/filters?q=)")

      assert json_response(conn, 400) == %{"error" => "Imbalanced parentheses."}
    end
  end
end
