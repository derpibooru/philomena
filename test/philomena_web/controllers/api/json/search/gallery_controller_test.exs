defmodule PhilomenaWeb.Api.Json.Search.GalleryControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  @moduletag :search

  import Philomena.GalleriesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Galleries.Gallery
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers

  setup do
    Search.clear_index!(Gallery)
    :ok
  end

  describe "GET /api/v1/json/search/galleries" do
    test "finds galleries by title", %{conn: conn} do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(user, title: "Chartreuse Alpacas", description: "Only the best")
      _other = gallery_fixture(user, title: "Something Else")
      SearchHelpers.reindex_all!(Gallery)

      conn = get(conn, ~p"/api/v1/json/search/galleries?q=title:chartreuse+alpacas")

      assert json_response(conn, 200) == %{
               "total" => 1,
               "galleries" => [
                 %{
                   "id" => gallery.id,
                   "title" => "Chartreuse Alpacas",
                   "thumbnail_id" => gallery.thumbnail_id,
                   "spoiler_warning" => gallery.spoiler_warning,
                   "description" => "Only the best",
                   "creator" => user.name,
                   "creator_id" => user.id
                 }
               ]
             }
    end

    test "returns an empty result for a missing query string", %{conn: conn} do
      user = confirmed_user_fixture()
      _gallery = gallery_fixture(user)
      SearchHelpers.reindex_all!(Gallery)

      # NOTE: a missing/empty q compiles to match_none, a 200 with no
      # results - not a 400.
      conn = get(conn, ~p"/api/v1/json/search/galleries")

      assert json_response(conn, 200) == %{"galleries" => [], "total" => 0}
    end

    test "returns 400 with a JSON error for an unparsable query", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/search/galleries?q=)")

      assert json_response(conn, 400) == %{"error" => "Imbalanced parentheses."}
    end
  end
end
