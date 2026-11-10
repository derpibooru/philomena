defmodule PhilomenaWeb.ProfileControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  @moduletag :search

  import Philomena.ArtistLinksFixtures
  import Philomena.CommentsFixtures
  import Philomena.ForumsFixtures
  import Philomena.ImagesFixtures
  import Philomena.PostsFixtures
  import Philomena.TagsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UserFingerprintsFixtures
  import Philomena.UserIpsFixtures
  import Philomena.UsersFixtures

  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers
  alias Philomena.Comments.Comment
  alias Philomena.Images.Image
  alias Philomena.Posts.Post
  alias Philomena.Repo

  setup do
    Search.clear_index!(Image)
    Search.clear_index!(Comment)
    Search.clear_index!(Post)
    :ok
  end

  describe "GET /profiles/:slug" do
    test "renders a profile for anonymous users", %{conn: conn} do
      user = confirmed_user_fixture(%{name: "Test Profile User"})

      user
      |> Ecto.Changeset.change(description: "All *about* this test user.")
      |> Repo.update!()

      conn = get(conn, ~p"/profiles/#{user}")
      response = html_response(conn, 200)

      assert response =~ "Test Profile User&#39;s profile - Derpibooru"
      assert response =~ "All <em>about</em> this test user."
      assert response =~ "Source changes"
    end

    test "renders a profile for logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      user = confirmed_user_fixture(%{name: "Test Profile User"})

      conn = get(conn, ~p"/profiles/#{user}")
      response = html_response(conn, 200)

      assert response =~ "Test Profile User&#39;s profile - Derpibooru"
      assert response =~ "Source changes"
    end

    test "renders profile edit affordances by ownership and staff role", %{conn: conn} do
      %{conn: conn, user: owner} = register_and_log_in_user(%{conn: conn})

      owner_response = html_response(get(conn, ~p"/profiles/#{owner}"), 200)

      assert owner_response =~ "Edit Personal Title"
      assert owner_response =~ ~p"/profiles/#{owner}/description/edit"

      other = confirmed_user_fixture()
      other_response = html_response(get(conn, ~p"/profiles/#{other}"), 200)

      refute other_response =~ ~p"/profiles/#{other}/description/edit"

      moderator_response =
        html_response(
          get(log_in_user(conn, moderator_user_fixture()), ~p"/profiles/#{other}"),
          200
        )

      assert moderator_response =~ "Edit Personal Title"
      assert moderator_response =~ ~p"/profiles/#{other}/description/edit"
    end

    test "renders the profile admin controls according to role abilities", %{conn: conn} do
      target = confirmed_user_fixture(%{name: "Admin Target"})

      moderator_response =
        html_response(
          get(log_in_user(conn, moderator_user_fixture()), ~p"/profiles/#{target}"),
          200
        )

      refute moderator_response =~ ~p"/admin/donations/user/#{target}"
      refute moderator_response =~ ~p"/admin/users/#{target}/edit"
      assert moderator_response =~ ~p"/profiles/#{target}/artist_links/new"
      assert moderator_response =~ ~p"/admin/user_bans/new?#{[user_id: target.id]}"
      assert moderator_response =~ ~p"/admin/reports?#{[rq: [query: "user_id:#{target.id}"]]}"
      refute moderator_response =~ ~p"/admin/users/#{target}/api_key"
      refute moderator_response =~ ~p"/admin/users/#{target}/verification"
      refute moderator_response =~ ~p"/admin/users/#{target}/votes"
      refute moderator_response =~ ~p"/admin/users/#{target}/erase/new"
      assert moderator_response =~ ~p"/profiles/#{target}/tag_changes/revert"

      %{conn: role_conn} = register_and_log_in_user_role_moderator(%{conn: conn})
      role_moderator_response = html_response(get(role_conn, ~p"/profiles/#{target}"), 200)

      assert role_moderator_response =~ ~p"/admin/users/#{target}/edit"
      assert role_moderator_response =~ ~p"/admin/users/#{target}/api_key"
      assert role_moderator_response =~ ~p"/admin/users/#{target}/verification"
      assert role_moderator_response =~ ~p"/admin/users/#{target}/votes"
      assert role_moderator_response =~ ~p"/admin/users/#{target}/downvotes"
      assert role_moderator_response =~ ~p"/admin/users/#{target}/erase/new"

      admin_response =
        html_response(
          get(log_in_user(conn, admin_user_fixture()), ~p"/profiles/#{target}"),
          200
        )

      assert admin_response =~ ~p"/admin/donations/user/#{target}"
      assert admin_response =~ ~p"/admin/users/#{target}/edit"
    end

    test "discloses profile moderation metadata only to staff", %{conn: conn} do
      target = confirmed_user_fixture()
      user_ip_fixture(target, "198.51.100.23")
      user_fingerprint_fixture(target, "cabcdef1234")

      anonymous_response = html_response(get(conn, ~p"/profiles/#{target}"), 200)

      refute anonymous_response =~ "Account created"
      refute anonymous_response =~ "198.51.100.23"
      refute anonymous_response =~ "cabcdef"

      regular_response =
        html_response(
          get(log_in_user(conn, confirmed_user_fixture()), ~p"/profiles/#{target}"),
          200
        )

      refute regular_response =~ "Account created"
      refute regular_response =~ "198.51.100.23"
      refute regular_response =~ "cabcdef"

      assistant_response =
        html_response(
          get(log_in_user(conn, assistant_user_fixture()), ~p"/profiles/#{target}"),
          200
        )

      refute assistant_response =~ "Account created"
      refute assistant_response =~ "198.51.100.23"
      refute assistant_response =~ "cabcdef"

      moderator_response =
        html_response(
          get(log_in_user(conn, moderator_user_fixture()), ~p"/profiles/#{target}"),
          200
        )

      assert moderator_response =~ "Account created"
      assert moderator_response =~ "198.51.100.23"
      assert moderator_response =~ "cabcdef"
    end

    test "renders ban history to the profile owner and ban-index staff", %{conn: conn} do
      target = banned_user_fixture()

      owner_response =
        html_response(get(log_in_user(conn, target), ~p"/profiles/#{target}"), 200)

      assert owner_response =~ "Ban History"

      other_response =
        html_response(
          get(log_in_user(conn, confirmed_user_fixture()), ~p"/profiles/#{target}"),
          200
        )

      refute other_response =~ "Ban History"

      moderator_response =
        html_response(
          get(log_in_user(conn, moderator_user_fixture()), ~p"/profiles/#{target}"),
          200
        )

      assert moderator_response =~ "Ban History"
    end

    test "omits recent comments whose images are hidden from the viewer", %{conn: conn} do
      target = confirmed_user_fixture()
      visible_image = image_fixture()
      hidden_image = image_fixture()
      _visible = comment_fixture(visible_image, target, %{"body" => "Visible profile comment"})
      _hidden = comment_fixture(hidden_image, target, %{"body" => "Hidden profile comment"})

      hidden_image
      |> Ecto.Changeset.change(hidden_from_users: true)
      |> Repo.update!()

      SearchHelpers.reindex_all!(Image)
      SearchHelpers.reindex_all!(Comment)

      response = html_response(get(conn, ~p"/profiles/#{target}"), 200)

      assert response =~ "Visible profile comment"
      refute response =~ "Hidden profile comment"
    end

    test "shows the source-history link to moderators", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      user = confirmed_user_fixture(%{name: "Test Profile User"})

      conn = get(conn, ~p"/profiles/#{user}")
      response = html_response(conn, 200)

      assert response =~ "Source changes"
      assert response =~ ~p"/profiles/#{user}/source_changes"
    end

    test "discloses artist-link tag watcher counts only to the owner or moderators", %{
      conn: conn
    } do
      owner = confirmed_user_fixture(%{name: "Watched Artist"})
      tag = tag_fixture(name: "artist:watched-artist")
      verified_artist_link_fixture(owner, tag)

      watcher = confirmed_user_fixture()

      watcher
      |> Ecto.Changeset.change(watched_tag_ids: [tag.id])
      |> Repo.update!()

      anonymous_response = html_response(get(conn, ~p"/profiles/#{owner}"), 200)
      refute anonymous_response =~ "Watched by 1 user"

      regular_response =
        html_response(
          get(log_in_user(conn, confirmed_user_fixture()), ~p"/profiles/#{owner}"),
          200
        )

      refute regular_response =~ "Watched by 1 user"

      owner_response =
        html_response(get(log_in_user(conn, owner), ~p"/profiles/#{owner}"), 200)

      assert owner_response =~ "Watched by 1 user"

      moderator_response =
        html_response(
          get(log_in_user(conn, moderator_user_fixture()), ~p"/profiles/#{owner}"),
          200
        )

      assert moderator_response =~ "Watched by 1 user"
    end

    test "shows recent uploads, comments, and posts", %{conn: conn} do
      user = confirmed_user_fixture(%{name: "Test Active User"})

      image = image_fixture(user_id: user.id)
      _comment = comment_fixture(image, user, %{"body" => "Test profile comment body"})

      topic = topic_fixture(forum_fixture(), user)
      _post = post_fixture(topic, user, %{"body" => "Test profile post body"})

      SearchHelpers.reindex_all!(Image)
      SearchHelpers.reindex_all!(Comment)
      SearchHelpers.reindex_all!(Post)

      conn = get(conn, ~p"/profiles/#{user}")
      response = html_response(conn, 200)

      assert response =~ ~p"/images/#{image.id}"
      assert response =~ "Test profile comment body"
      assert response =~ topic.title
      assert response =~ ~p"/comments?#{[cq: "author_id:#{user.id}"]}"
      assert response =~ ~p"/posts?#{[pq: "author_id:#{user.id}"]}"
      refute response =~ "q=user_id"
    end

    test "redirects to / for an unknown slug", %{conn: conn} do
      conn = get(conn, ~p"/profiles/nonexistent-user")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    test "hides a deactivated profile from the public but not from moderators", %{conn: conn} do
      user = deactivated_user_fixture()

      public_conn = get(conn, ~p"/profiles/#{user}")

      assert redirected_to(public_conn) == "/"

      assert Phoenix.Flash.get(public_conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"

      moderator_response =
        html_response(
          get(log_in_user(conn, moderator_user_fixture()), ~p"/profiles/#{user}"),
          200
        )

      assert moderator_response =~ user.name
      assert moderator_response =~ ~p"/profiles/#{user}/ip_history"

      admin_response =
        html_response(get(log_in_user(conn, admin_user_fixture()), ~p"/profiles/#{user}"), 200)

      assert admin_response =~ "Reactivate Account"
    end
  end
end
