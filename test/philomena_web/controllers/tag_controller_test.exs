defmodule PhilomenaWeb.TagControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  # The read-only actions (:index, :show) and the moderation actions
  # (:edit, :update, :delete) are covered here. Tags are keyed by slug, so
  # the "by-id" endpoints have no non-integer-id crash; unknown slugs are
  # pinned instead.

  @moduletag :search

  import Philomena.ChannelsFixtures
  import Philomena.ImagesFixtures
  import Philomena.TagsFixtures
  import Philomena.UsersFixtures

  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers
  alias Philomena.Images.Image
  alias Philomena.Repo
  alias Philomena.Tags.Tag

  setup do
    Search.clear_index!(Tag)
    Search.clear_index!(Image)
    :ok
  end

  describe "GET /tags" do
    test "renders matching tags for anonymous users", %{conn: conn} do
      tag = tag_fixture(name: "test searchable tag")
      _other = tag_fixture(name: "test unrelated tag")
      SearchHelpers.reindex_all!(Tag)

      conn = get(conn, ~p"/tags?tq=test searchable tag")
      response = html_response(conn, 200)

      assert response =~ "Tags - Derpibooru"
      assert response =~ "test searchable tag"
      refute response =~ "test unrelated tag"
      assert response =~ ~p"/tags/#{tag}"
    end

    test "lists all tags with the default query", %{conn: conn} do
      _one = tag_fixture(name: "test first tag")
      _two = tag_fixture(name: "test second tag")
      SearchHelpers.reindex_all!(Tag)

      conn = get(conn, ~p"/tags")
      response = html_response(conn, 200)

      assert response =~ "test first tag"
      assert response =~ "test second tag"
    end
  end

  describe "GET /tags/:slug" do
    test "renders a tag with its images for anonymous users", %{conn: conn} do
      tag = tag_fixture(name: "test shown tag")

      tag
      |> Ecto.Changeset.change(description: "A tag *described* in markdown.")
      |> Repo.update!()

      image = image_fixture(tags: "safe, test shown tag")
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/tags/#{tag}")
      response = html_response(conn, 200)

      assert response =~ "test shown tag - Tags - Derpibooru"
      assert response =~ "A tag <em>described</em> in markdown."
      assert response =~ ~p"/images/#{image.id}"
    end

    test "redirects an aliased tag to its target", %{conn: conn} do
      target = tag_fixture(name: "test target tag")
      aliased = tag_fixture(name: "test aliased tag")

      aliased
      |> Ecto.Changeset.change(aliased_tag_id: target.id)
      |> Repo.update!()

      conn = get(conn, ~p"/tags/#{aliased}")

      assert redirected_to(conn) == ~p"/tags/#{target}"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               ~s|This tag ("test aliased tag") has been aliased into the tag "test target tag".|
    end

    test "redirects to / with not-found for an unknown slug", %{conn: conn} do
      conn = get(conn, ~p"/tags/nonexistent-tag")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "renders channel edit affordances only to channel moderators", %{conn: conn} do
      tag = tag_fixture(name: "artist:tag-channel-affordance")

      channel =
        listed_channel_fixture(%{"artist_tag" => tag.name}, %{title: "Tagged Stream"})

      anonymous_response = html_response(get(conn, ~p"/tags/#{tag}"), 200)
      assert anonymous_response =~ "Tagged Stream"
      refute anonymous_response =~ ~p"/channels/#{channel}/edit"

      moderator_response =
        html_response(get(log_in_user(conn, moderator_user_fixture()), ~p"/tags/#{tag}"), 200)

      assert moderator_response =~ "Tagged Stream"
      assert moderator_response =~ ~p"/channels/#{channel}/edit"
    end
  end

  describe "GET /tags/:slug/edit" do
    test "is a login redirect for anonymous users", %{conn: conn} do
      tag = tag_fixture()
      conn = get(conn, ~p"/tags/#{tag}/edit")

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "is rejected for regular users", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, confirmed_user_fixture())
      conn = get(conn, ~p"/tags/#{tag}/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
    end

    test "renders the edit form for a moderator", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, moderator_user_fixture())
      conn = get(conn, ~p"/tags/#{tag}/edit")

      assert html_response(conn, 200) =~ "Editing Tag"
    end

    test "renders alias-management affordances only to tag managers", %{conn: conn} do
      tag = tag_fixture()

      moderator_response =
        html_response(
          get(log_in_user(conn, moderator_user_fixture()), ~p"/tags/#{tag}/edit"),
          200
        )

      refute moderator_response =~ ~p"/tags/#{tag}/alias/edit"
      refute moderator_response =~ "Tag Processing"

      admin_response =
        html_response(get(log_in_user(conn, admin_user_fixture()), ~p"/tags/#{tag}/edit"), 200)

      assert admin_response =~ ~p"/tags/#{tag}/alias/edit"
      assert admin_response =~ "Tag Processing"

      role_response =
        html_response(
          get(log_in_role_moderator(conn, "Tag"), ~p"/tags/#{tag}/edit"),
          200
        )

      assert role_response =~ ~p"/tags/#{tag}/alias/edit"
      assert role_response =~ "Tag Processing"
    end

    test "renders the edit form for a moderator without a fingerprint", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, moderator_user_fixture())
      conn = get(without_fingerprint(conn), ~p"/tags/#{tag}/edit")

      assert html_response(conn, 200) =~ "Editing Tag"
    end
  end

  describe "PUT/PATCH /tags/:slug (update)" do
    test "is a login redirect for anonymous users", %{conn: conn} do
      tag = tag_fixture()
      conn = put(conn, ~p"/tags/#{tag}", %{"tag" => %{"category" => "character"}})

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "is rejected for regular users", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, confirmed_user_fixture())
      conn = put(conn, ~p"/tags/#{tag}", %{"tag" => %{"category" => "character"}})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
    end

    test "a moderator updates the tag (PATCH)", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, moderator_user_fixture())

      conn =
        patch(conn, ~p"/tags/#{tag}", %{
          "tag" => %{"category" => "character", "description" => "a described tag"}
        })

      assert redirected_to(conn) == ~p"/tags/#{tag}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Tag successfully updated"

      tag = Repo.get!(Tag, tag.id)
      assert tag.category == "character"
      assert tag.description == "a described tag"
    end

    test "a moderator updates the tag (PUT)", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, moderator_user_fixture())

      conn = put(conn, ~p"/tags/#{tag}", %{"tag" => %{"short_description" => "short desc"}})

      assert redirected_to(conn) == ~p"/tags/#{tag}"
      assert Repo.get!(Tag, tag.id).short_description == "short desc"
    end

    test "an unknown slug is the not-found redirect for a moderator", %{conn: conn} do
      conn = log_in_user(conn, moderator_user_fixture())
      conn = put(conn, ~p"/tags/nonexistent-tag", %{"tag" => %{"category" => "character"}})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "an unknown slug is the not-found redirect for an admin", %{conn: conn} do
      # NOTE: can?(admin, _, nil) is true, so the admin is authorized on the
      # nil load and the context returns not_found before update/2 runs - a
      # clean "Couldn't find" redirect, NOT a crash. Same
      # different-flash-by-role split as the tag alias/reindex children.
      conn = log_in_user(conn, admin_user_fixture())
      conn = put(conn, ~p"/tags/nonexistent-tag", %{"tag" => %{"category" => "character"}})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, moderator_user_fixture())

      conn =
        patch(without_fingerprint(conn), ~p"/tags/#{tag}", %{
          "tag" => %{"category" => "character"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get!(Tag, tag.id).category == tag.category
    end
  end

  describe "DELETE /tags/:slug" do
    test "is a login redirect for anonymous users", %{conn: conn} do
      tag = tag_fixture()
      conn = delete(conn, ~p"/tags/#{tag}")

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "is rejected for regular users", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, confirmed_user_fixture())
      conn = delete(conn, ~p"/tags/#{tag}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
    end

    test "is rejected for a plain moderator", %{conn: conn} do
      # NOTE: :delete is *not* mapped to :edit, so a plain moderator (who only
      # has :edit on tags) is denied deletion; only an admin or a Tag-admin
      # role_map moderator can delete a tag.
      tag = tag_fixture()
      conn = log_in_user(conn, moderator_user_fixture())
      conn = delete(conn, ~p"/tags/#{tag}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
      assert Repo.get(Tag, tag.id)
    end

    test "an admin queues the tag for deletion", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, admin_user_fixture())
      conn = delete(conn, ~p"/tags/#{tag}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Tag queued for deletion"

      # NOTE: delete_tag only enqueues a (dead) TagDeleteWorker, so the row is
      # still present synchronously.
      assert Repo.get(Tag, tag.id)
    end

    test "a rating tag is not deleted", %{conn: conn} do
      tag = tag_fixture(category: "rating")
      conn = log_in_user(conn, admin_user_fixture())
      conn = delete(conn, ~p"/tags/#{tag}")

      assert redirected_to(conn) == ~p"/tags/#{tag}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Rating tags cannot be deleted"
      assert Repo.get(Tag, tag.id)
    end

    test "a Tag-admin role_map moderator can delete", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_role_moderator(conn, "Tag")
      conn = delete(conn, ~p"/tags/#{tag}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Tag queued for deletion"
    end

    test "an unknown slug is the not-found redirect for an admin", %{conn: conn} do
      # NOTE: the delete_tag failure surface is the unknown slug; an admin
      # passes authorization on the nil load, so the context returns not_found
      # before delete/2 - a clean "Couldn't find" redirect, not a crash.
      conn = log_in_user(conn, admin_user_fixture())
      conn = delete(conn, ~p"/tags/nonexistent-tag")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end
end
