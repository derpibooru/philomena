defmodule PhilomenaWeb.Api.Json.Forum.Topic.PostControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ForumsFixtures
  import Philomena.PostsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Notifications
  alias Philomena.Notifications.ForumPostNotification
  alias Philomena.Posts
  alias Philomena.Repo
  alias Philomena.Topics

  describe "GET /api/v1/json/forums/:forum_id/topics/:topic_id/posts" do
    test "lists posts in topic-position order", %{conn: conn} do
      user = confirmed_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum, user, %{"posts" => %{"0" => %{"body" => "First post"}}})
      reply = post_fixture(topic, user, %{"body" => "Second post"})

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts")

      assert %{"posts" => [first, second], "total" => 2} = json_response(conn, 200)

      assert %{"body" => "First post", "author" => author} = first
      assert author == user.name
      assert %{"body" => "Second post", "id" => reply_id} = second
      assert reply_id == reply.id
    end

    test "leaves the key holder's topic notification unread", %{conn: conn} do
      user = confirmed_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum)
      {:ok, _} = Topics.create_subscription(topic, user)

      {:ok, 1} =
        Notifications.broadcast_forum_post(confirmed_user_fixture(), topic, hd(topic.posts))

      conn =
        get(
          conn,
          ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts?key=#{user.authentication_token}"
        )

      assert %{"posts" => [_]} = json_response(conn, 200)
      assert Repo.get_by(ForumPostNotification, topic_id: topic.id, user_id: user.id)
    end

    test "does not exclude hidden posts", %{conn: conn} do
      user = confirmed_user_fixture()
      moderator = moderator_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum, user)
      reply = post_fixture(topic, user, %{"body" => "Rule-breaking reply"})

      {:ok, _} =
        Posts.create_post_hide(
          Philomena.AttributionFixtures.actor(moderator),
          forum.short_name,
          topic.slug,
          reply.id,
          %{"deletion_reason" => "spam"}
        )

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts")

      assert %{"posts" => [first, second], "total" => 2} = json_response(conn, 200)
      refute first["id"] == reply.id
      refute first["body"] == nil
      assert second["id"] == reply.id
      assert second["body"] == nil
    end

    test "includes hidden posts for moderators", %{conn: conn} do
      moderator = moderator_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum)
      reply = post_fixture(topic, nil, %{"body" => "Rule-breaking reply"})

      {:ok, _} =
        Posts.create_post_hide(
          Philomena.AttributionFixtures.actor(moderator),
          forum.short_name,
          topic.slug,
          reply.id,
          %{"deletion_reason" => "spam"}
        )

      conn =
        get(
          conn,
          ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts?key=#{moderator.authentication_token}"
        )

      assert %{"posts" => posts, "total" => 2} = json_response(conn, 200)
      assert Enum.any?(posts, &(&1["id"] == reply.id))
    end

    test "paginates in windows of 25 by topic position by default", %{conn: conn} do
      user = confirmed_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum, user)

      for n <- 1..25,
          do:
            post_fixture(topic, confirmed_user_fixture(), %{
              "body" => "Reply number #{n}"
            })

      conn2 = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts?page=2")

      assert %{"posts" => [last], "total" => 26} = json_response(conn2, 200)
      assert %{"body" => "Reply number 25"} = last

      # A non-integer per_page falls back to the default window of 25.
      conn3 =
        get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts?page=2&per_page=zebra")

      assert %{"posts" => [%{"body" => "Reply number 25"}], "total" => 26} =
               json_response(conn3, 200)
    end

    test "honors per_page when windowing by topic position", %{conn: conn} do
      user = confirmed_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum, user, %{"posts" => %{"0" => %{"body" => "First post"}}})
      post_fixture(topic, user, %{"body" => "Second post"})
      post_fixture(topic, user, %{"body" => "Third post"})

      conn1 = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts?per_page=1")

      assert %{"posts" => [%{"body" => "First post"}], "total" => 3} = json_response(conn1, 200)

      conn2 = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts?per_page=1&page=2")

      assert %{"posts" => [%{"body" => "Second post"}], "total" => 3} = json_response(conn2, 200)

      # per_page is clamped to a minimum of 1.
      conn3 = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts?per_page=0")

      assert %{"posts" => [%{"body" => "First post"}], "total" => 3} = json_response(conn3, 200)
    end

    test "jumps to the page holding post_id", %{conn: conn} do
      user = confirmed_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum, user)

      replies =
        for n <- 1..26,
            do: post_fixture(topic, confirmed_user_fixture(), %{"body" => "Reply #{n}"})

      last = List.last(replies)

      conn =
        get(
          conn,
          ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts?#{[post_id: last.id]}"
        )

      assert %{"posts" => [%{"id" => id, "body" => "Reply 25"}, %{"id" => last_id}]} =
               json_response(conn, 200)

      assert id == Enum.at(replies, 24).id
      assert last_id == last.id
    end

    test "returns 404 for an unknown topic or forum", %{conn: conn} do
      forum = forum_fixture()

      # NOTE: the total now comes from the topic (loaded up front), so an
      # unknown topic or forum 404s instead of crashing on hd([]).
      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/nonexistent/posts")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns no results for a page past the last post", %{conn: conn} do
      forum = forum_fixture()
      topic = topic_fixture(forum)

      # Scrivener clamps an out-of-range page to the final valid page.
      # The database-backed pagination used for topics does not.
      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts?page=2")

      total = Repo.reload!(topic).post_count
      assert %{"posts" => [], "total" => ^total} = json_response(conn, 200)
    end
  end

  describe "GET /api/v1/json/forums/:forum_id/topics/:topic_id/posts/:id" do
    test "shows a post", %{conn: conn} do
      user = confirmed_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum, user)
      post = post_fixture(topic, user, %{"body" => "A signed reply"})

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts/#{post.id}")

      %{"post" => body} = json_response(conn, 200)

      # NOTE: the avatar of a user without an uploaded avatar is a generated
      # SVG data URI, so it is asserted by shape only.
      {avatar, body} = Map.pop(body, "avatar")
      assert is_binary(avatar)

      assert body == %{
               "id" => post.id,
               "user_id" => user.id,
               "author" => user.name,
               "body" => "A signed reply",
               "created_at" => DateTime.to_iso8601(post.created_at),
               "updated_at" => DateTime.to_iso8601(post.updated_at),
               "edited_at" => nil,
               "edit_reason" => nil
             }
    end

    test "returns 404 for a destroyed post", %{conn: conn} do
      forum = forum_fixture()
      topic = topic_fixture(forum)
      post = post_fixture(topic, nil)

      {:ok, _} =
        Posts.create_post_hide(
          Philomena.AttributionFixtures.actor(moderator_user_fixture()),
          forum.short_name,
          topic.slug,
          post.id,
          %{deletion_reason: "Spam"}
        )

      {:ok, _} =
        Posts.create_post_delete(
          Philomena.AttributionFixtures.actor(moderator_user_fixture()),
          forum.short_name,
          topic.slug,
          post.id
        )

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts/#{post.id}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns 404 for a post in a hidden topic", %{conn: conn} do
      moderator = moderator_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum)
      post = post_fixture(topic, nil)

      {:ok, {_forum, _topic}} =
        Topics.create_topic_hide(
          Philomena.AttributionFixtures.actor(moderator),
          forum.short_name,
          topic.slug,
          %{"deletion_reason" => "spam"}
        )

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts/#{post.id}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns 404 for a post under the wrong topic slug", %{conn: conn} do
      forum = forum_fixture()
      topic = topic_fixture(forum)
      other_topic = topic_fixture(forum)
      post = post_fixture(topic, nil)

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{other_topic}/posts/#{post.id}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns 404 for a post in a restricted forum", %{conn: conn} do
      forum = forum_fixture(access_level: "staff")
      topic = topic_fixture(forum)
      post = post_fixture(topic, moderator_user_fixture())

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts/#{post.id}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns 404 for an unknown id", %{conn: conn} do
      forum = forum_fixture()
      topic = topic_fixture(forum)

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts/#{0}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns 404 for a non-integer id", %{conn: conn} do
      forum = forum_fixture()
      topic = topic_fixture(forum)

      # NOTE: the id is now parsed first, so a non-integer id 404s like an
      # unknown id rather than raising a cast error.
      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts/not-a-number")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end
  end
end
