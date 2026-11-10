defmodule PhilomenaWeb.Profile.IpHistoryControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures
  import Philomena.UserIpsFixtures

  describe "GET /profiles/:profile_id/ip_history" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      user = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{user}/ip_history")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "redirects a regular user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      other = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{other}/ip_history")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "renders the history and cross-references other users on the same IP", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      subject = confirmed_user_fixture()
      alias_user = confirmed_user_fixture()

      user_ip_fixture(subject, "203.0.113.7")
      user_ip_fixture(alias_user, "203.0.113.7")

      response = html_response(get(conn, ~p"/profiles/#{subject}/ip_history"), 200)

      assert response =~ "IP History for"
      assert response =~ subject.name
      assert response =~ alias_user.name
    end

    test "renders an empty history when the user has no IP rows", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      subject = confirmed_user_fixture()

      response = html_response(get(conn, ~p"/profiles/#{subject}/ip_history"), 200)

      assert response =~ "IP History for"
      assert response =~ subject.name
    end

    test "redirects an unknown profile slug with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(conn, ~p"/profiles/#{"nonexistent-slug"}/ip_history")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end
  end
end
