defmodule PhilomenaWeb.Tag.AliasControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # All three actions authorize :alias on the tag, which a *plain*
  # moderator lacks (they only have :edit), so only an admin or a Tag-admin
  # role_map moderator can reach them. The actual alias/unalias work is a
  # dead Exq enqueue; only the synchronous aliased_tag_id write on :update
  # is observable. Tags are slug-keyed.

  import Philomena.TagsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Repo
  alias Philomena.Tags.Tag

  describe "GET /tags/:tag_id/alias/edit" do
    test "is a login redirect for anonymous users", %{conn: conn} do
      tag = tag_fixture()
      conn = get(conn, ~p"/tags/#{tag}/alias/edit")

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "is rejected for regular users", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, confirmed_user_fixture())
      conn = get(conn, ~p"/tags/#{tag}/alias/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
    end

    test "is rejected for a plain moderator", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, moderator_user_fixture())
      conn = get(conn, ~p"/tags/#{tag}/alias/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
    end

    test "renders the edit form for an admin", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, admin_user_fixture())
      conn = get(conn, ~p"/tags/#{tag}/alias/edit")

      assert html_response(conn, 200) =~ "Editing Tag Alias"
    end

    test "renders the edit form for a Tag-admin role_map moderator", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_role_moderator(conn, "Tag")
      conn = get(conn, ~p"/tags/#{tag}/alias/edit")

      assert html_response(conn, 200) =~ "Editing Tag Alias"
    end

    test "renders the edit form for an admin without a fingerprint", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, admin_user_fixture())
      conn = get(without_fingerprint(conn), ~p"/tags/#{tag}/alias/edit")

      assert html_response(conn, 200) =~ "Editing Tag Alias"
    end
  end

  describe "PUT/PATCH /tags/:tag_id/alias (update)" do
    test "is rejected for a plain moderator", %{conn: conn} do
      tag = tag_fixture()
      target = tag_fixture(name: "target tag alias")
      conn = log_in_user(conn, moderator_user_fixture())
      conn = patch(conn, ~p"/tags/#{tag}/alias", %{"tag" => %{"target_tag" => target.name}})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
    end

    test "an admin aliases the tag into the target (PATCH)", %{conn: conn} do
      tag = tag_fixture()
      target = tag_fixture(name: "target tag alias")
      conn = log_in_user(conn, admin_user_fixture())

      conn = patch(conn, ~p"/tags/#{tag}/alias", %{"tag" => %{"target_tag" => target.name}})

      assert redirected_to(conn) == ~p"/tags/#{tag}/alias/edit"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Tag alias queued"

      assert Repo.get!(Tag, tag.id).aliased_tag_id == target.id
    end

    test "an admin aliases the tag into the target (PUT)", %{conn: conn} do
      tag = tag_fixture()
      target = tag_fixture(name: "target tag alias")
      conn = log_in_user(conn, admin_user_fixture())

      conn = put(conn, ~p"/tags/#{tag}/alias", %{"tag" => %{"target_tag" => target.name}})

      assert redirected_to(conn) == ~p"/tags/#{tag}/alias/edit"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Tag alias queued"

      assert Repo.get!(Tag, tag.id).aliased_tag_id == target.id
    end

    test "an admin aliases into a target typed with different case and spacing", %{conn: conn} do
      tag = tag_fixture()
      target = tag_fixture(name: "target tag alias")
      conn = log_in_user(conn, admin_user_fixture())

      conn =
        patch(conn, ~p"/tags/#{tag}/alias", %{"tag" => %{"target_tag" => " Target  Tag Alias "}})

      assert redirected_to(conn) == ~p"/tags/#{tag}/alias/edit"
      assert Repo.get!(Tag, tag.id).aliased_tag_id == target.id
    end

    test "a blank target re-renders the form with an error", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, admin_user_fixture())

      conn = patch(conn, ~p"/tags/#{tag}/alias", %{"tag" => %{"target_tag" => ""}})

      assert html_response(conn, 200) =~ "can&#39;t be blank"
      assert Repo.get!(Tag, tag.id).aliased_tag_id == nil
    end

    test "an unknown target re-renders the form with an error", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, admin_user_fixture())

      conn = patch(conn, ~p"/tags/#{tag}/alias", %{"tag" => %{"target_tag" => "no such tag"}})

      assert html_response(conn, 200) =~ "does not exist"
      assert Repo.get!(Tag, tag.id).aliased_tag_id == nil
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      tag = tag_fixture()
      target = tag_fixture(name: "target tag alias")
      conn = log_in_user(conn, admin_user_fixture())

      conn =
        patch(without_fingerprint(conn), ~p"/tags/#{tag}/alias", %{
          "tag" => %{"target_tag" => target.name}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.get!(Tag, tag.id).aliased_tag_id
    end
  end

  describe "DELETE /tags/:tag_id/alias" do
    test "is rejected for a plain moderator", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, moderator_user_fixture())
      conn = delete(conn, ~p"/tags/#{tag}/alias")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
    end

    test "an admin dealiases the tag", %{conn: conn} do
      target = tag_fixture(name: "target tag dealias")

      tag =
        tag_fixture()
        |> Ecto.Changeset.change(aliased_tag_id: target.id)
        |> Repo.update!()

      conn = log_in_user(conn, admin_user_fixture())
      conn = delete(conn, ~p"/tags/#{tag}/alias")

      assert redirected_to(conn) == ~p"/tags/#{tag}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Tag dealias successful"
      assert Repo.get!(Tag, tag.id).aliased_tag_id == nil
    end

    test "dealiasing a tag that is not aliased redirects back with an error", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, admin_user_fixture())
      conn = delete(conn, ~p"/tags/#{tag}/alias")

      assert redirected_to(conn) == ~p"/tags/#{tag}/alias/edit"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not aliased"
    end

    test "an unknown slug is the not-found redirect for a role_map moderator", %{
      conn: conn
    } do
      conn = log_in_role_moderator(conn, "Tag")
      conn = delete(conn, ~p"/tags/nonexistent-tag/alias")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "an unknown slug is the not-found redirect for an admin", %{conn: conn} do
      # NOTE: can?(admin, _, nil) is true, so the admin is authorized on the
      # nil load and the context returns not_found before delete/2 runs - a
      # clean "Couldn't find" redirect, NOT a crash.
      conn = log_in_user(conn, admin_user_fixture())
      conn = delete(conn, ~p"/tags/nonexistent-tag/alias")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end
end
