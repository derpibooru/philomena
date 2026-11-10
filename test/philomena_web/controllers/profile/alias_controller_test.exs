defmodule PhilomenaWeb.Profile.AliasControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures
  import Philomena.UserIpsFixtures
  import Philomena.UserFingerprintsFixtures

  describe "GET /profiles/:profile_id/aliases" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      user = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{user}/aliases")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "redirects a regular user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      other = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{other}/aliases")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "lists a user sharing both an IP and a fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      subject = confirmed_user_fixture()
      alias_user = confirmed_user_fixture()

      user_ip_fixture(subject, "203.0.113.9")
      user_ip_fixture(alias_user, "203.0.113.9")
      user_fingerprint_fixture(subject, "aliasfp")
      user_fingerprint_fixture(alias_user, "aliasfp")

      response = html_response(get(conn, ~p"/profiles/#{subject}/aliases"), 200)

      assert response =~ "Potential Aliases"
      assert response =~ alias_user.name
    end

    test "lists a user sharing only an IP", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      subject = confirmed_user_fixture()
      alias_user = confirmed_user_fixture()

      user_ip_fixture(subject, "203.0.113.10")
      user_ip_fixture(alias_user, "203.0.113.10")

      response = html_response(get(conn, ~p"/profiles/#{subject}/aliases"), 200)

      assert response =~ "Potential Aliases"
      assert response =~ alias_user.name
    end

    test "renders an empty alias page when nothing is shared", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      subject = confirmed_user_fixture()

      user_ip_fixture(subject, "203.0.113.11")

      response = html_response(get(conn, ~p"/profiles/#{subject}/aliases"), 200)

      assert response =~ "Potential Aliases"
    end

    test "redirects an unknown profile slug with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(conn, ~p"/profiles/#{"nonexistent-slug"}/aliases")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end
end
