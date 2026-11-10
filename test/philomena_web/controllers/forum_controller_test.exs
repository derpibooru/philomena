defmodule PhilomenaWeb.ForumControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ForumsFixtures

  describe "GET /forums" do
    test "renders the forum list for anonymous users", %{conn: conn} do
      forum = forum_fixture(name: "Pony Discussion", description: "Pones")

      conn = get(conn, ~p"/forums")
      response = html_response(conn, 200)

      assert response =~ "Forums - Derpibooru"
      assert response =~ "Discussion Forums"
      assert response =~ "Pony Discussion"
      assert response =~ ~p"/forums/#{forum}"
    end

    test "does not list restricted forums to anonymous users", %{conn: conn} do
      _normal = forum_fixture(name: "Pony Discussion")
      _staff = forum_fixture(name: "Staff Lounge", access_level: "staff")
      _assistant = forum_fixture(name: "Assistant Lounge", access_level: "assistant")

      conn = get(conn, ~p"/forums")
      response = html_response(conn, 200)

      refute response =~ "Staff Lounge"
      refute response =~ "Assistant Lounge"
    end

    test "renders an empty index when the user can see no forums", %{conn: conn} do
      _staff = forum_fixture(name: "Staff Lounge", access_level: "staff")

      # NOTE: an empty forum list renders cleanly - nothing probes the first
      # element of the loaded list, so a user who can see zero forums gets an
      # empty index rather than a 500.
      conn = get(conn, ~p"/forums")
      response = html_response(conn, 200)

      assert response =~ "Forums - Derpibooru"
      assert response =~ "Discussion Forums"
      refute response =~ "Staff Lounge"
    end
  end

  describe "GET /forums/:short_name" do
    test "renders a normal forum for anonymous users", %{conn: conn} do
      forum = forum_fixture(name: "Site and Policy", description: "For site discussion")

      conn = get(conn, ~p"/forums/#{forum}")
      response = html_response(conn, 200)

      assert response =~ "Site and Policy - Derpibooru"
      assert response =~ "For site discussion"
    end

    test "redirects to / for an unknown short name", %{conn: conn} do
      # NOTE: an unknown forum is a 302 redirect with a flash, not a 404 page
      # (unlike the JSON API, which returns a bare 404) - and the flash is the
      # not-found message.
      conn = get(conn, ~p"/forums/nonexistent")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "redirects to / for a restricted forum", %{conn: conn} do
      forum = forum_fixture(access_level: "staff")

      # NOTE: indistinguishable from the unknown-forum case above.
      conn = get(conn, ~p"/forums/#{forum}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You can't access that page."
    end
  end
end
