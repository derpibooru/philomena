defmodule PhilomenaWeb.Admin.User.VoteControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # Postgres-only. The actual vote/fave wipe is performed by UserUnvoteWorker,
  # which is only enqueued (a dead Exq enqueue in test), so only the
  # flash/redirect and the synchronous moderation_log insert are observable
  # here.

  import Philomena.UsersFixtures

  # NOTE: gated on `can?(:edit, %User{})` (matching the parent edit form), which
  # a plain moderator lacks - so starting a vote and fave wipe is admin-only (or a
  # User-role_map moderator).

  describe "DELETE /admin/users/:user_id/votes authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = delete(conn, ~p"/admin/users/#{target.slug}/votes")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      target = confirmed_user_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = delete(conn, ~p"/admin/users/#{target.slug}/votes")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "DELETE /admin/users/:user_id/votes" do
    setup [:register_and_log_in_admin]

    test "enqueues the wipe and redirects to their profile", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = delete(conn, ~p"/admin/users/#{target.slug}/votes")
      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Vote and fave wipe started"
    end

    # NOTE: :delete runs the not_found handler, so an unknown slug redirects.
    test "redirects for an unknown slug", %{conn: conn} do
      conn = delete(conn, ~p"/admin/users/no-such-user/votes")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end

  describe "DELETE /admin/users/:user_id/votes as a plain moderator" do
    setup [:register_and_log_in_moderator]

    # NOTE: the wipe is performed by an (unconsumed) UserUnvoteWorker enqueue, so
    # there is no observable side effect to assert absent - the denial redirect +
    # flash is the pin.
    test "is denied to a plain moderator", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = delete(conn, ~p"/admin/users/#{target.slug}/votes")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end
end
