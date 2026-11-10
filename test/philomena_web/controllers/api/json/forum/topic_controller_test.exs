defmodule PhilomenaWeb.Api.Json.Forum.TopicControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ForumsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Repo
  alias Philomena.Topics

  describe "GET /api/v1/json/forums/:forum_id/topics" do
    test "lists topics with sticky topics first", %{conn: conn} do
      user = confirmed_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum, user, %{"title" => "Regular topic"})

      sticky =
        topic_fixture(forum, user, %{"title" => "Sticky topic"})
        |> Ecto.Changeset.change(sticky: true)
        |> Repo.update!()

      topic = Repo.reload!(topic)
      sticky = Repo.reload!(sticky)

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics")

      assert json_response(conn, 200) == %{
               "total" => 2,
               "topics" => [
                 %{
                   "slug" => sticky.slug,
                   "title" => "Sticky topic",
                   "post_count" => 1,
                   "view_count" => 0,
                   "sticky" => true,
                   "last_replied_to_at" => DateTime.to_iso8601(sticky.last_replied_to_at),
                   "locked" => false,
                   "user_id" => user.id,
                   "author" => user.name
                 },
                 %{
                   "slug" => topic.slug,
                   "title" => "Regular topic",
                   "post_count" => 1,
                   "view_count" => 0,
                   "sticky" => false,
                   "last_replied_to_at" => DateTime.to_iso8601(topic.last_replied_to_at),
                   "locked" => false,
                   "user_id" => user.id,
                   "author" => user.name
                 }
               ]
             }
    end

    test "excludes hidden topics for users", %{conn: conn} do
      moderator = moderator_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum)

      {:ok, {_forum, _topic}} =
        Topics.create_topic_hide(
          Philomena.AttributionFixtures.actor(moderator),
          forum.short_name,
          topic.slug,
          %{"deletion_reason" => "spam"}
        )

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics")

      assert json_response(conn, 200) == %{"topics" => [], "total" => 0}
    end

    test "excludes hidden topics for moderators", %{conn: conn} do
      moderator = moderator_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum)

      {:ok, {_forum, _topic}} =
        Topics.create_topic_hide(
          Philomena.AttributionFixtures.actor(moderator),
          forum.short_name,
          topic.slug,
          %{"deletion_reason" => "spam"}
        )

      conn =
        get(
          conn,
          ~p"/api/v1/json/forums/#{forum}/topics?key=#{moderator.authentication_token}"
        )

      assert %{"topics" => [], "total" => 0} = json_response(conn, 200)
    end

    test "returns 404 for an unknown forum", %{conn: conn} do
      # NOTE: unlike the show action, an unknown forum is a 200 with an empty
      # list, not a 404.
      conn = get(conn, ~p"/api/v1/json/forums/nonexistent/topics")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns 404 for a restricted forum", %{conn: conn} do
      forum = forum_fixture(access_level: "staff")
      _topic = topic_fixture(forum)

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "shows restricted forums to staff", %{conn: conn} do
      moderator = moderator_user_fixture()
      forum = forum_fixture(access_level: "staff")
      _topic = topic_fixture(forum)

      conn =
        get(conn, ~p"/api/v1/json/forums/#{forum}/topics?key=#{moderator.authentication_token}")

      assert %{"topics" => [_], "total" => 1} = json_response(conn, 200)
    end

    test "paginates with page and per_page", %{conn: conn} do
      forum = forum_fixture()
      for n <- 1..3, do: topic_fixture(forum, nil, %{"title" => "Topic number #{n}"})

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics?page=2&per_page=2")

      assert %{"topics" => [_], "total" => 3} = json_response(conn, 200)
    end
  end

  describe "GET /api/v1/json/forums/:forum_id/topics/:slug" do
    test "shows a topic by slug", %{conn: conn} do
      user = confirmed_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum, user, %{"title" => "An Interesting Discussion"})
      topic = Repo.reload!(topic)

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}")

      assert json_response(conn, 200) == %{
               "topic" => %{
                 "slug" => topic.slug,
                 "title" => "An Interesting Discussion",
                 "post_count" => 1,
                 "view_count" => 0,
                 "sticky" => false,
                 "last_replied_to_at" => DateTime.to_iso8601(topic.last_replied_to_at),
                 "locked" => false,
                 "user_id" => user.id,
                 "author" => user.name
               }
             }
    end

    test "attributes an anonymous topic to Background Pony", %{conn: conn} do
      forum = forum_fixture()
      topic = topic_fixture(forum, nil)

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}")

      assert %{"topic" => %{"user_id" => nil, "author" => author}} = json_response(conn, 200)
      assert author =~ ~r/\ABackground Pony #[0-9A-F]{4}\z/
    end

    test "returns 404 for a hidden topic", %{conn: conn} do
      moderator = moderator_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum)

      {:ok, {_forum, _topic}} =
        Topics.create_topic_hide(
          Philomena.AttributionFixtures.actor(moderator),
          forum.short_name,
          topic.slug,
          %{"deletion_reason" => "spam"}
        )

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns 404 for a topic in a restricted forum", %{conn: conn} do
      forum = forum_fixture(access_level: "staff")
      topic = topic_fixture(forum)

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns 404 for a topic slug under the wrong forum", %{conn: conn} do
      forum = forum_fixture()
      other_forum = forum_fixture()
      topic = topic_fixture(forum)

      conn = get(conn, ~p"/api/v1/json/forums/#{other_forum}/topics/#{topic}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns 404 for an unknown slug", %{conn: conn} do
      forum = forum_fixture()

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/nonexistent")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end
  end
end
