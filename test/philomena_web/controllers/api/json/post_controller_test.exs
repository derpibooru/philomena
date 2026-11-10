defmodule PhilomenaWeb.Api.Json.PostControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ForumsFixtures
  import Philomena.PostsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Posts
  alias Philomena.Topics

  describe "GET /api/v1/json/posts/:id" do
    test "shows a signed post", %{conn: conn} do
      user = confirmed_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum)
      post = post_fixture(topic, user, %{"body" => "A signed post"})

      conn = get(conn, ~p"/api/v1/json/posts/#{post.id}")

      %{"post" => body} = json_response(conn, 200)

      # NOTE: the avatar of a user without an uploaded avatar is a generated
      # SVG data URI, so it is asserted by shape only.
      {avatar, body} = Map.pop(body, "avatar")
      assert is_binary(avatar)

      assert body == %{
               "id" => post.id,
               "user_id" => user.id,
               "author" => user.name,
               "body" => "A signed post",
               "created_at" => DateTime.to_iso8601(post.created_at),
               "updated_at" => DateTime.to_iso8601(post.updated_at),
               "edited_at" => nil,
               "edit_reason" => nil
             }
    end

    test "hides the author of an anonymous post", %{conn: conn} do
      user = confirmed_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum)
      post = post_fixture(topic, user, %{"body" => "Anon post", "anonymous" => "true"})

      conn = get(conn, ~p"/api/v1/json/posts/#{post.id}")

      assert %{"post" => %{"user_id" => nil, "author" => author}} = json_response(conn, 200)
      assert author =~ ~r/\ABackground Pony #[0-9A-F]{4}\z/
    end

    test "returns 404 for a hidden post", %{conn: conn} do
      user = confirmed_user_fixture()
      moderator = moderator_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum)
      post = post_fixture(topic, user, %{"body" => "Rule-breaking post"})

      {:ok, _} =
        Posts.create_post_hide(
          Philomena.AttributionFixtures.actor(moderator),
          forum.short_name,
          topic.slug,
          post.id,
          %{"deletion_reason" => "spam"}
        )

      conn = get(conn, ~p"/api/v1/json/posts/#{post.id}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
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

      conn = get(conn, ~p"/api/v1/json/posts/#{post.id}")

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

      conn = get(conn, ~p"/api/v1/json/posts/#{post.id}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns 404 for a post in a restricted forum", %{conn: conn} do
      forum = forum_fixture(access_level: "staff")
      topic = topic_fixture(forum)
      post = post_fixture(topic, moderator_user_fixture())

      conn = get(conn, ~p"/api/v1/json/posts/#{post.id}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns 404 for an unknown id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/posts/#{0}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns 404 for a non-integer id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/posts/not-a-number")
      assert json_response(conn, 404) == %{"error" => "Not found"}
    end
  end
end
