defmodule PhilomenaWeb.Admin.User.EraseControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # Postgres-only. Users.erase_user/2 synchronously deactivates and renames
  # the account, then enqueues UserEraseWorker for the rest (a dead Exq
  # enqueue in test); the rename also enqueues (dead) UserRenameWorker. So
  # the deactivation and rename are observable, but the deeper deletion is
  # not.

  import Philomena.UsersFixtures

  alias Philomena.Users.User
  alias Philomena.Repo

  # NOTE: gated on `can?(:edit, %User{})` (matching the parent edit form), which
  # a plain moderator lacks - so erasing a user is admin-only (or a User-role_map
  # moderator).

  describe "GET /admin/users/:user_id/erase/new authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = get(conn, ~p"/admin/users/#{target.slug}/erase/new")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      target = confirmed_user_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/users/#{target.slug}/erase/new")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "GET /admin/users/:user_id/erase/new" do
    setup [:register_and_log_in_admin]

    test "renders the erase confirmation form for an ordinary user", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = get(conn, ~p"/admin/users/#{target.slug}/erase/new")
      assert html_response(conn, 200) =~ "Erase user"
    end

    # NOTE: the prevent_deleting_nonexistent_users guard catches the nil loaded
    # for an unknown slug (before context authorization would apply on :new),
    # redirecting to the user index with a custom flash instead of crashing.
    test "redirects an unknown slug to the user index", %{conn: conn} do
      conn = get(conn, ~p"/admin/users/no-such-user/erase/new")
      assert redirected_to(conn) == ~p"/admin/users"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find that username"
    end

    test "refuses to erase a privileged user", %{conn: conn} do
      target = moderator_user_fixture()
      conn = get(conn, ~p"/admin/users/#{target.slug}/erase/new")
      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Cannot erase a privileged user"
    end

    test "refuses to erase a verified user", %{conn: conn} do
      target = verified_user_fixture()
      conn = get(conn, ~p"/admin/users/#{target.slug}/erase/new")
      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Cannot erase a verified user"
    end

    test "renders the erase confirmation form without a fingerprint", %{conn: conn} do
      target = confirmed_user_fixture()

      conn = get(without_fingerprint(conn), ~p"/admin/users/#{target.slug}/erase/new")

      assert html_response(conn, 200) =~ "Erase user"
    end
  end

  describe "POST /admin/users/:user_id/erase (create) authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = post(conn, ~p"/admin/users/#{target.slug}/erase")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      target = confirmed_user_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = post(conn, ~p"/admin/users/#{target.slug}/erase")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "POST /admin/users/:user_id/erase (create)" do
    setup [:register_and_log_in_admin]

    test "deactivates and renames the user, then redirects to their profile", %{conn: conn} do
      target = confirmed_user_fixture()

      conn = post(conn, ~p"/admin/users/#{target.slug}/erase")

      assert redirected_to(conn) =~ "/profiles/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "User erase started"

      reloaded = Repo.get(User, target.id)
      assert reloaded.deleted_at != nil
      assert reloaded.name =~ ~r/^deactivated_[0-9a-f]{32}$/
    end

    test "erases an already deactivated user, keeping its deactivation", %{conn: conn} do
      target = deactivated_user_fixture()

      conn = post(conn, ~p"/admin/users/#{target.slug}/erase")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "User erase started"

      reloaded = Repo.get(User, target.id)
      assert reloaded.name =~ ~r/^deactivated_[0-9a-f]{32}$/
      assert reloaded.deleted_at == target.deleted_at
      assert reloaded.deleted_by_user_id == target.id
    end

    # NOTE: the nonexistent-user guard redirects to the user index (no crash)
    # for an unknown slug - the create write action's failure path.
    test "redirects an unknown slug to the user index", %{conn: conn} do
      conn = post(conn, ~p"/admin/users/no-such-user/erase")
      assert redirected_to(conn) == ~p"/admin/users"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find that username"
    end

    test "refuses to erase a privileged user", %{conn: conn} do
      target = moderator_user_fixture()
      conn = post(conn, ~p"/admin/users/#{target.slug}/erase")
      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Cannot erase a privileged user"
      # unchanged
      assert Repo.get(User, target.id).deleted_at == nil
    end

    test "refuses to erase a verified user", %{conn: conn} do
      target = verified_user_fixture()
      conn = post(conn, ~p"/admin/users/#{target.slug}/erase")
      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Cannot erase a verified user"
      assert Repo.get(User, target.id).deleted_at == nil
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      target = confirmed_user_fixture()

      conn = post(without_fingerprint(conn), ~p"/admin/users/#{target.slug}/erase")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.get(User, target.id).deleted_at
    end
  end

  describe "POST /admin/users/:user_id/erase (create) as a banned admin" do
    setup [:register_and_log_in_banned_admin]

    test "gives the ban response without erasing", %{conn: conn} do
      target = confirmed_user_fixture()

      conn = post(conn, ~p"/admin/users/#{target.slug}/erase")

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You are currently banned."
      assert Repo.get(User, target.id).deleted_at == nil
    end
  end

  describe "POST /admin/users/:user_id/erase (create) as a plain moderator" do
    setup [:register_and_log_in_moderator]

    test "is denied to a plain moderator", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = post(conn, ~p"/admin/users/#{target.slug}/erase")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."

      # unchanged: the account is neither deactivated nor renamed
      reloaded = Repo.get(User, target.id)
      assert reloaded.deleted_at == nil
      refute reloaded.name =~ ~r/^deactivated_/
    end
  end
end
