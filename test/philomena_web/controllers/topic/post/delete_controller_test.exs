defmodule PhilomenaWeb.Topic.Post.DeleteControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # "Delete" here is the destroy-content tool (blanks the body), the tier
  # above hide.

  import Philomena.ForumsFixtures
  import Philomena.PostsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Posts
  alias Philomena.Repo

  setup do
    forum = forum_fixture()
    topic = topic_fixture(forum)
    post = post_fixture(topic, nil, %{"body" => "Original post body"})

    {:ok, post} =
      Posts.create_post_hide(
        Philomena.AttributionFixtures.actor(moderator_user_fixture()),
        forum.short_name,
        topic.slug,
        post.id,
        %{deletion_reason: "Spam"}
      )

    %{forum: forum, topic: topic, post: post}
  end

  defp post_anchor(forum, topic, post) do
    ~p"/forums/#{forum}/topics/#{topic}?#{[post_id: post.id]}" <> "#post_#{post.id}"
  end

  describe "POST /forums/:forum_id/topics/:topic_id/posts/:post_id/delete" do
    test "redirects anonymous users to the login page",
         %{conn: conn, forum: forum, topic: topic, post: post} do
      conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/delete")

      assert redirected_to(conn) == ~p"/sessions/new"
      refute Repo.reload!(post).destroyed_content
    end

    test "rejects a regular user with the authorization flash",
         %{conn: conn, forum: forum, topic: topic, post: post} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/delete")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.reload!(post).destroyed_content
    end

    test "as a moderator destroys the post content",
         %{conn: conn, forum: forum, topic: topic, post: post} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/delete")

      assert redirected_to(conn) == post_anchor(forum, topic, post)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Post successfully destroyed!"

      post = Repo.reload!(post)
      assert post.destroyed_content
      assert post.body == ""
    end

    # Failure path: destroy_changeset never fails, so the only reachable failure
    # surface is an unknown post - the context authorizes the nil load, which no
    # moderator rule matches, so it returns unauthorized and redirects with the
    # authorization flash.
    test "for an unknown post_id redirects with the not-found flash",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/999999999/delete")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    # NOTE: a non-integer post_id short-circuits to NotFoundPlug via the central
    # IntegerId guard, redirecting with the not-found flash.
    test "for a non-integer post_id redirects with the not-found flash",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/not-a-number/delete")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end
  end
end
