defmodule PhilomenaWeb.FingerprintProfileControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures
  import Philomena.UserFingerprintsFixtures

  describe "GET /fingerprint_profiles/:id" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      conn = get(conn, ~p"/fingerprint_profiles/#{"abc123"}")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "redirects a regular user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/fingerprint_profiles/#{"d015c342859dde3"}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "renders the profile and lists users seen on the fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      user = confirmed_user_fixture()
      user_fingerprint_fixture(user, "d015c342859dde3")

      response =
        html_response(get(conn, ~p"/fingerprint_profiles/#{"d015c342859dde3"}"), 200)

      assert response =~ "d015c342859dde3&#39;s fingerprint profile"
      assert response =~ user.name
      assert response =~ ~p"/admin/reports?#{[rq: [query: "fingerprint:d015c342859dde3"]]}"
    end

    test "renders an empty profile for a valid fingerprint with no activity", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      response =
        html_response(get(conn, ~p"/fingerprint_profiles/#{"d11111111111111"}"), 200)

      assert response =~ "d11111111111111&#39;s fingerprint profile"
    end

    test "redirects with a not-found flash for an invalid fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(conn, ~p"/fingerprint_profiles/#{"not-a-fingerprint"}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end
end
