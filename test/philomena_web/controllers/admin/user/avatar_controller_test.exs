defmodule PhilomenaWeb.Admin.User.AvatarControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # Postgres-only: the S3 delete in Users.delete_avatar/1 goes through the
  # stubbed ex_aws client and the reindex is a dead Exq enqueue;
  # moderation_log/2 is a synchronous insert.

  import Philomena.UsersFixtures

  alias Philomena.Users.User
  alias Philomena.Repo

  # NOTE: gated on `can?(:edit, %User{})` (matching the parent edit form), which
  # a plain moderator lacks - so removing another user's avatar is admin-only
  # (or a User-role_map moderator).

  describe "DELETE /admin/users/:user_id/avatar authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      target = user_with_avatar_fixture()
      conn = delete(conn, ~p"/admin/users/#{target.slug}/avatar")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      target = user_with_avatar_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = delete(conn, ~p"/admin/users/#{target.slug}/avatar")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "DELETE /admin/users/:user_id/avatar" do
    setup [:register_and_log_in_admin]

    test "removes the avatar and redirects to the admin edit page", %{conn: conn} do
      target = user_with_avatar_fixture()
      assert Repo.get(User, target.id).avatar == "test/avatar.png"

      conn = delete(conn, ~p"/admin/users/#{target.slug}/avatar")

      assert redirected_to(conn) == ~p"/admin/users/#{target}/edit"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "removed avatar"
      assert Repo.get(User, target.id).avatar == nil
    end

    # NOTE: succeeds even when the user has no avatar - remove_avatar_changeset
    # just sets avatar: nil unconditionally.
    test "still succeeds when the user has no avatar", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = delete(conn, ~p"/admin/users/#{target.slug}/avatar")
      assert redirected_to(conn) == ~p"/admin/users/#{target}/edit"
      assert Repo.get(User, target.id).avatar == nil
    end

    # NOTE: an unknown slug loads nil and the actor is authorized on it, so
    # :delete returns not_found - a redirect to "/" with the not-found flash
    # instead of crashing.
    test "redirects for an unknown slug", %{conn: conn} do
      conn = delete(conn, ~p"/admin/users/no-such-user/avatar")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end

  describe "DELETE /admin/users/:user_id/avatar as a plain moderator" do
    setup [:register_and_log_in_moderator]

    test "is denied to a plain moderator", %{conn: conn} do
      target = user_with_avatar_fixture()
      conn = delete(conn, ~p"/admin/users/#{target.slug}/avatar")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      # unchanged: the avatar is untouched
      assert Repo.get(User, target.id).avatar == "test/avatar.png"
    end
  end
end
