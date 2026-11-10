defmodule PhilomenaWeb.Profile.TagChange.RevertControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # full_revert only enqueues a (dead) TagChangeRevertWorker, so there is
  # nothing to observe beyond the flash and redirect.

  import Philomena.UsersFixtures

  describe "POST /profiles/:profile_id/tag_changes/revert" do
    test "is rejected for anonymous users", %{conn: conn} do
      user = confirmed_user_fixture()
      conn = post(conn, ~p"/profiles/#{user}/tag_changes/revert")

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "is rejected for regular users", %{conn: conn} do
      user = confirmed_user_fixture()
      conn = log_in_user(conn, confirmed_user_fixture())
      conn = post(conn, ~p"/profiles/#{user}/tag_changes/revert")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
    end

    test "a moderator enqueues a reversion for a user", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = log_in_user(conn, moderator_user_fixture())
      conn = post(conn, ~p"/profiles/#{target}/tag_changes/revert")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Reversion of tag changes enqueued"
    end

    test "a moderator enqueues a reversion for an ip", %{conn: conn} do
      conn = log_in_user(conn, moderator_user_fixture())
      conn = post(conn, ~p"/ip_profiles/203.0.113.5/tag_changes/revert")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Reversion of tag changes enqueued"
    end

    test "a moderator enqueues a reversion for a fingerprint", %{conn: conn} do
      conn = log_in_user(conn, moderator_user_fixture())
      conn = post(conn, ~p"/fingerprint_profiles/c1774/tag_changes/revert")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Reversion of tag changes enqueued"
    end

    test "a malformed target redirects with the failure flash", %{conn: conn} do
      conn = log_in_user(conn, moderator_user_fixture())

      conn = post(conn, ~p"/ip_profiles/not-an-ip/tag_changes/revert")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end
  end
end
