defmodule PhilomenaWeb.Admin.User.VerificationControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # Postgres-only: reindex is a dead Exq enqueue, moderation_log/2 is a
  # synchronous insert.

  import Philomena.UsersFixtures

  alias Philomena.Users.User
  alias Philomena.Repo

  # NOTE: gated on `can?(:edit, %User{})` (matching the parent edit form), which
  # a plain moderator lacks - so granting or revoking verification is admin-only
  # (or a User-role_map moderator).

  describe "POST /admin/users/:user_id/verification (grant) authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = post(conn, ~p"/admin/users/#{target.slug}/verification")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      target = confirmed_user_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = post(conn, ~p"/admin/users/#{target.slug}/verification")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "POST /admin/users/:user_id/verification (grant)" do
    setup [:register_and_log_in_admin]

    test "verifies the user and redirects to their profile", %{conn: conn} do
      target = confirmed_user_fixture()
      refute Repo.get(User, target.id).verified

      conn = post(conn, ~p"/admin/users/#{target.slug}/verification")

      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "verification granted"
      assert Repo.get(User, target.id).verified
    end

    # NOTE: the context authorizes the loaded record on :create; an unknown slug
    # loads nil, the actor is authorized on it, so it redirects with the
    # not-found flash rather than passing nil into Users.verify_user/1.
    test "redirects with the not-found flash for an unknown slug", %{conn: conn} do
      conn = post(conn, ~p"/admin/users/no-such-user/verification")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end

  describe "POST /admin/users/:user_id/verification (grant) as a plain moderator" do
    setup [:register_and_log_in_moderator]

    test "is denied to a plain moderator", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = post(conn, ~p"/admin/users/#{target.slug}/verification")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      # unchanged: the user stays unverified
      refute Repo.get(User, target.id).verified
    end
  end

  describe "DELETE /admin/users/:user_id/verification (revoke) authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      target = verified_user_fixture()
      conn = delete(conn, ~p"/admin/users/#{target.slug}/verification")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      target = verified_user_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = delete(conn, ~p"/admin/users/#{target.slug}/verification")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "DELETE /admin/users/:user_id/verification (revoke)" do
    setup [:register_and_log_in_admin]

    test "unverifies the user and redirects to their profile", %{conn: conn} do
      target = verified_user_fixture()
      assert Repo.get(User, target.id).verified

      conn = delete(conn, ~p"/admin/users/#{target.slug}/verification")

      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "verification revoked"
      refute Repo.get(User, target.id).verified
    end

    # NOTE: :delete DOES run the not_found handler, so an unknown slug redirects.
    test "redirects for an unknown slug", %{conn: conn} do
      conn = delete(conn, ~p"/admin/users/no-such-user/verification")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end

  describe "DELETE /admin/users/:user_id/verification (revoke) as a plain moderator" do
    setup [:register_and_log_in_moderator]

    test "is denied to a plain moderator", %{conn: conn} do
      target = verified_user_fixture()
      conn = delete(conn, ~p"/admin/users/#{target.slug}/verification")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      # unchanged: the user stays verified
      assert Repo.get(User, target.id).verified
    end
  end
end
