defmodule PhilomenaWeb.IpProfile.SourceChangeControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ImagesFixtures
  import Philomena.SourceChangesFixtures

  describe "GET /ip_profiles/:ip_profile_id/source_changes" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      conn = get(conn, ~p"/ip_profiles/#{"203.0.113.1"}/source_changes")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "the route's login requirement runs before malformed IP validation", %{conn: conn} do
      conn = get(conn, ~p"/ip_profiles/#{"not-an-ip"}/source_changes")

      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You must log in"
    end

    test "redirects a regular user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/ip_profiles/#{"203.0.113.1"}/source_changes")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "lists source changes attributed to the IP", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()
      source_change_fixture(image, ip: "203.0.113.1", source_url: "https://pinned.example/art")

      response = html_response(get(conn, ~p"/ip_profiles/#{"203.0.113.1"}/source_changes"), 200)

      assert response =~ "Source changes by"
      assert response =~ "https://pinned.example/art"
    end

    test "renders an empty listing for an IP with no source changes", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      response =
        html_response(get(conn, ~p"/ip_profiles/#{"203.0.113.99"}/source_changes"), 200)

      assert response =~ "Source changes by"
    end

    # NOTE: an unparsable IP now takes the NotFoundPlug path (302 to / with the
    # not-found flash) rather than raising MatchError.
    test "redirects with the not-found flash on an unparsable IP", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(conn, ~p"/ip_profiles/#{"not-an-ip"}/source_changes")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "redirects with an error flash for an invalid filter", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(conn, ~p"/ip_profiles/#{"203.0.113.1"}/source_changes?added=invalid")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid source change filter."
    end
  end
end
