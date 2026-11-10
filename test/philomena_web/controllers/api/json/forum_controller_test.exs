defmodule PhilomenaWeb.Api.Json.ForumControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ForumsFixtures

  describe "GET /api/v1/json/forums" do
    test "returns an empty list when no forums exist", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/forums")

      assert json_response(conn, 200) == %{"forums" => [], "total" => 0}
    end

    test "lists normal-access forums sorted by name, excluding restricted forums", %{conn: conn} do
      bravo = forum_fixture(name: "Bravo", description: "Second forum")
      alpha = forum_fixture(name: "Alpha", description: "First forum")
      _staff = forum_fixture(name: "Aardvark", access_level: "staff")
      _assistant = forum_fixture(name: "Abacus", access_level: "assistant")

      conn = get(conn, ~p"/api/v1/json/forums")

      assert json_response(conn, 200) == %{
               "total" => 2,
               "forums" => [
                 %{
                   "name" => "Alpha",
                   "short_name" => alpha.short_name,
                   "description" => "First forum",
                   "topic_count" => 0,
                   "post_count" => 0
                 },
                 %{
                   "name" => "Bravo",
                   "short_name" => bravo.short_name,
                   "description" => "Second forum",
                   "topic_count" => 0,
                   "post_count" => 0
                 }
               ]
             }
    end
  end

  describe "GET /api/v1/json/forums/:short_name" do
    test "shows a forum by short name", %{conn: conn} do
      forum = forum_fixture(name: "Site and Policy", description: "For site discussion")

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}")

      assert json_response(conn, 200) == %{
               "forum" => %{
                 "name" => "Site and Policy",
                 "short_name" => forum.short_name,
                 "description" => "For site discussion",
                 "topic_count" => 0,
                 "post_count" => 0
               }
             }
    end

    test "returns 404 for an unknown short name", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/forums/nonexistent")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns 404 for a forum with a restricted access level", %{conn: conn} do
      forum = forum_fixture(access_level: "staff")

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end
  end
end
