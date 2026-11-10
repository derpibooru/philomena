defmodule PhilomenaWeb.FingerprintProfile.SourceChangeControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ImagesFixtures
  import Philomena.SourceChangesFixtures

  describe "GET /fingerprint_profiles/:fingerprint_profile_id/source_changes" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      conn = get(conn, ~p"/fingerprint_profiles/#{"c123"}/source_changes")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "the route's login requirement runs before malformed fingerprint validation", %{
      conn: conn
    } do
      conn = get(conn, ~p"/fingerprint_profiles/#{"not-a-fingerprint"}/source_changes")

      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You must log in"
    end

    test "redirects a regular user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/fingerprint_profiles/#{"c123"}/source_changes")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "lists source changes attributed to the fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      source_change_fixture(image,
        fingerprint: "c123",
        source_url: "https://pinned.example/fp-art"
      )

      response =
        html_response(get(conn, ~p"/fingerprint_profiles/#{"c123"}/source_changes"), 200)

      assert response =~ "Source changes by"
      assert response =~ "https://pinned.example/fp-art"
    end

    test "renders an empty listing for a valid fingerprint with no source changes", %{
      conn: conn
    } do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      response =
        html_response(get(conn, ~p"/fingerprint_profiles/#{"c999"}/source_changes"), 200)

      assert response =~ "Source changes by"
    end

    test "uses the not-found response for a malformed fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(conn, ~p"/fingerprint_profiles/#{"no-such-fp"}/source_changes")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end
end
