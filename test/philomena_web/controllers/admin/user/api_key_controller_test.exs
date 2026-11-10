defmodule PhilomenaWeb.Admin.User.ApiKeyControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # Postgres-only.

  import Philomena.UsersFixtures

  alias Philomena.Users.User
  alias Philomena.Repo

  # NOTE: gated on `can?(:edit, %User{})` (matching the parent edit form), which
  # a plain moderator lacks - so resetting a user's API token is admin-only (or a
  # User-role_map moderator).

  describe "DELETE /admin/users/:user_id/api_key authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = delete(conn, ~p"/admin/users/#{target.slug}/api_key")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      target = confirmed_user_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = delete(conn, ~p"/admin/users/#{target.slug}/api_key")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "DELETE /admin/users/:user_id/api_key" do
    setup [:register_and_log_in_admin]

    test "resets the token and redirects to their profile", %{conn: conn} do
      target = confirmed_user_fixture()
      old_token = target.authentication_token

      conn = delete(conn, ~p"/admin/users/#{target.slug}/api_key")

      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "API token successfully reset"

      new_token = Repo.get(User, target.id).authentication_token
      assert new_token != old_token
      assert is_binary(new_token)
    end

    # NOTE: :delete runs the not_found handler, so an unknown slug redirects.
    test "redirects for an unknown slug", %{conn: conn} do
      conn = delete(conn, ~p"/admin/users/no-such-user/api_key")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end

  describe "DELETE /admin/users/:user_id/api_key as a plain moderator" do
    setup [:register_and_log_in_moderator]

    test "is denied to a plain moderator", %{conn: conn} do
      target = confirmed_user_fixture()
      old_token = target.authentication_token
      conn = delete(conn, ~p"/admin/users/#{target.slug}/api_key")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      # unchanged: the API token is untouched
      assert Repo.get(User, target.id).authentication_token == old_token
    end
  end
end
