defmodule PhilomenaWeb.Admin.User.WipeControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # Postgres-only. The actual PII wipe is performed by UserWipeWorker, which
  # is only enqueued (a dead Exq enqueue in test), so only the flash/redirect
  # and the synchronous moderation_log insert are observable here.

  import Philomena.UsersFixtures

  # NOTE: gated on `can?(:edit, %User{})` (matching the parent edit form), which
  # a plain moderator lacks - so queuing a PII wipe is admin-only (or a
  # User-role_map moderator).

  describe "POST /admin/users/:user_id/wipe authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = post(conn, ~p"/admin/users/#{target.slug}/wipe")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      target = confirmed_user_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = post(conn, ~p"/admin/users/#{target.slug}/wipe")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "POST /admin/users/:user_id/wipe" do
    setup [:register_and_log_in_admin]

    test "queues the wipe and redirects to their profile", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = post(conn, ~p"/admin/users/#{target.slug}/wipe")
      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "PII wipe queued"
    end

    # NOTE: the context authorizes the loaded record on :create; an unknown slug
    # loads nil, the admin is authorized on it, so it redirects with the
    # not-found flash rather than dereferencing a nil user.
    test "redirects with the not-found flash for an unknown slug", %{conn: conn} do
      conn = post(conn, ~p"/admin/users/no-such-user/wipe")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end

  describe "POST /admin/users/:user_id/wipe as a plain moderator" do
    setup [:register_and_log_in_moderator]

    # NOTE: the wipe is performed by an (unconsumed) UserWipeWorker enqueue, so
    # there is no observable side effect to assert absent - the denial redirect +
    # flash is the pin.
    test "is denied to a plain moderator", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = post(conn, ~p"/admin/users/#{target.slug}/wipe")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end
end
