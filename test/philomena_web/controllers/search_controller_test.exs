defmodule PhilomenaWeb.SearchControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  @moduletag :search

  import Philomena.ImagesFixtures

  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers
  alias Philomena.Images.Image
  alias Philomena.Tags.Tag

  setup do
    Search.clear_index!(Image)
    # The search form renders the quick tag table, which queries the tags
    # index (TagView.lookup_quick_tags/1) the first time it is built in a
    # test run.
    Search.clear_index!(Tag)
    :ok
  end

  describe "GET /search" do
    test "renders matching images for anonymous users", %{conn: conn} do
      wanted = image_fixture(tags: "safe, test wanted tag")
      other = image_fixture(tags: "safe, test unrelated tag")
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/search?q=test wanted tag")
      response = html_response(conn, 200)

      assert response =~ "Searching for test wanted tag - Derpibooru"
      assert response =~ ~p"/images/#{wanted.id}"
      refute response =~ ~p"/images/#{other.id}"
    end

    test "renders matching images for logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/search?q=safe")

      assert html_response(conn, 200) =~ ~p"/images/#{image.id}"
    end

    test "renders a page number far past the search window", %{conn: conn} do
      conn = get(conn, ~p"/search?q=safe&page=999999999999")

      assert html_response(conn, 200)
    end

    test "renders with no query", %{conn: conn} do
      image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/search")
      response = html_response(conn, 200)

      # NOTE: the nil query is interpolated into the title, leaving a double
      # space; it compiles to match_none, so nothing is listed.
      assert response =~ "Searching for  - Derpibooru"
      refute response =~ ~p"/images/#{image.id}"
    end

    test "renders an error for an invalid query", %{conn: conn} do
      conn = get(conn, ~p"/search?q=(")
      response = html_response(conn, 200)

      assert response =~ "Searching for ( - Derpibooru"
      assert response =~ "there was an error parsing your query"
    end

    test "uses relevance ordering with a custom sort field", %{conn: conn} do
      image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/search?q=safe&sf=score")

      assert html_response(conn, 200) =~ ~p"/images/#{image.id}"
    end
  end
end
