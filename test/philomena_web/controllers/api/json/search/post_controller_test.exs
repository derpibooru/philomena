defmodule PhilomenaWeb.Api.Json.Search.PostControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  @moduletag :search

  import Philomena.ForumsFixtures
  import Philomena.PostsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Posts
  alias Philomena.Posts.Post
  alias Philomena.Topics
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers

  setup do
    Search.clear_index!(Post)
    :ok
  end

  describe "GET /api/v1/json/search/posts" do
    test "finds posts by body", %{conn: conn} do
      user = confirmed_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum, user)
      post = post_fixture(topic, user, %{"body" => "chartreuse alpaca"})
      SearchHelpers.reindex_all!(Post)

      conn = get(conn, ~p"/api/v1/json/search/posts?q=chartreuse")

      assert %{"total" => 1, "posts" => [found]} = json_response(conn, 200)
      assert %{"id" => id, "body" => "chartreuse alpaca", "author" => author} = found
      assert id == post.id
      assert author == user.name
    end

    test "excludes hidden posts and posts in restricted forums for anonymous actors", %{
      conn: conn
    } do
      moderator = moderator_user_fixture()
      forum = forum_fixture()
      staff_forum = forum_fixture(access_level: "staff")
      topic = topic_fixture(forum, nil, %{"posts" => %{"0" => %{"body" => "chartreuse llama"}}})

      _staff_topic =
        topic_fixture(staff_forum, nil, %{"posts" => %{"0" => %{"body" => "chartreuse vicuna"}}})

      hidden = post_fixture(topic, nil, %{"body" => "chartreuse guanaco"})

      {:ok, _} =
        Posts.create_post_hide(
          Philomena.AttributionFixtures.actor(moderator),
          forum.short_name,
          topic.slug,
          hidden.id,
          %{"deletion_reason" => "spam"}
        )

      SearchHelpers.reindex_all!(Post)

      conn = get(conn, ~p"/api/v1/json/search/posts?q=chartreuse")

      assert %{"total" => 1, "posts" => [%{"body" => "chartreuse llama"}]} =
               json_response(conn, 200)
    end

    test "allows moderators to search posts in restricted forums", %{conn: conn} do
      moderator = moderator_user_fixture()
      staff_forum = forum_fixture(access_level: "staff")

      post =
        staff_forum
        |> topic_fixture()
        |> post_fixture(admin_user_fixture(), %{"body" => "chartreuse vicuna"})

      SearchHelpers.reindex_all!(Post)

      conn =
        get(
          conn,
          ~p"/api/v1/json/search/posts?q=chartreuse&key=#{moderator.authentication_token}"
        )

      assert %{"total" => 1, "posts" => [%{"id" => id, "body" => "chartreuse vicuna"}]} =
               json_response(conn, 200)

      assert id == post.id
    end

    test "excludes a matched post whose topic is hidden", %{conn: conn} do
      moderator = moderator_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum, nil, %{"posts" => %{"0" => %{"body" => "chartreuse okapi"}}})

      {:ok, {_forum, _topic}} =
        Topics.create_topic_hide(
          Philomena.AttributionFixtures.actor(moderator),
          forum.short_name,
          topic.slug,
          %{"deletion_reason" => "spam"}
        )

      SearchHelpers.reindex_all!(Post)

      conn = get(conn, ~p"/api/v1/json/search/posts?q=chartreuse")

      # NOTE: a post in a hidden topic is folded to hidden_from_users: true in
      # the index (as_json/1 indexes `post.hidden_from_users or
      # post.topic.hidden_from_users`), so the endpoint's hardcoded
      # hidden_from_users: false filter excludes it entirely - it is neither
      # returned nor counted in total.
      assert json_response(conn, 200) == %{"total" => 0, "posts" => []}
    end

    test "restores a post to search when its topic is unhidden", %{conn: conn} do
      moderator = moderator_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum, nil, %{"posts" => %{"0" => %{"body" => "chartreuse okapi"}}})

      # Hiding the topic and reindexing folds its posts to hidden, excluding them.
      {:ok, {_forum, hidden_topic}} =
        Topics.create_topic_hide(
          Philomena.AttributionFixtures.actor(moderator),
          forum.short_name,
          topic.slug,
          %{"deletion_reason" => "spam"}
        )

      SearchHelpers.reindex_all!(Post)

      conn = get(conn, ~p"/api/v1/json/search/posts?q=chartreuse")
      assert json_response(conn, 200) == %{"total" => 0, "posts" => []}

      # Unhiding it (which enqueues a topic-wide post reindex in production; here
      # we drive the reindex explicitly) folds the posts back to visible, so the
      # post is searchable again with its real body.
      {:ok, {_forum, _topic}} =
        Topics.delete_topic_hide(
          Philomena.AttributionFixtures.actor(moderator),
          forum.short_name,
          hidden_topic.slug
        )

      SearchHelpers.reindex_all!(Post)

      conn = get(conn, ~p"/api/v1/json/search/posts?q=chartreuse")

      assert %{"total" => 1, "posts" => [%{"body" => "chartreuse okapi"}]} =
               json_response(conn, 200)
    end

    test "returns an empty result for a missing query string", %{conn: conn} do
      # NOTE: a missing/empty q compiles to match_none, a 200 with no
      # results - not a 400.
      conn = get(conn, ~p"/api/v1/json/search/posts")

      assert json_response(conn, 200) == %{"posts" => [], "total" => 0}
    end

    test "returns 400 with a JSON error for an unparsable query", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/search/posts?q=)")

      assert json_response(conn, 400) == %{"error" => "Imbalanced parentheses."}
    end
  end
end
