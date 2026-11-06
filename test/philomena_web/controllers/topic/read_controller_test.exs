defmodule PhilomenaWeb.Topic.ReadControllerTest do
  use PhilomenaWeb.ConnCase, async: true
  use PhilomenaWeb.SingletonToggleTests

  import Ecto.Query
  import Philomena.ForumsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Forums
  alias Philomena.Notifications
  alias Philomena.Notifications.ForumPostNotification
  alias Philomena.Notifications.ForumTopicNotification
  alias Philomena.Repo
  alias Philomena.Topics

  # require_authenticated_user halts before the resource loads, so the ids in
  # this path need not exist.
  defp anonymous_path, do: ~p"/forums/dummy/topics/1/read"

  defp read_target(user) do
    forum = forum_fixture()
    topic = topic_fixture(forum)

    %{
      path: ~p"/forums/#{forum}/topics/#{topic}/read",
      arrange!: fn ->
        {:ok, _} = Topics.create_subscription(topic, user)
        author = confirmed_user_fixture()
        post = hd(topic.posts)
        {:ok, 1} = Notifications.broadcast_forum_post(author, topic, post)
      end,
      notification?: fn ->
        Repo.exists?(
          from n in ForumPostNotification,
            where: n.topic_id == ^topic.id and n.user_id == ^user.id
        )
      end
    }
  end

  read_singleton_tests()

  test "POST for an unknown topic redirects to / with the not-found flash", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    forum = forum_fixture()

    conn = post(conn, ~p"/forums/#{forum}/topics/nonexistent-topic/read")

    assert redirected_to(conn) == "/"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "Couldn't find what you were looking for!"
  end

  test "POST for a hidden topic still clears the notification", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    forum = forum_fixture()
    topic = topic_fixture(forum)
    {:ok, _} = Topics.create_subscription(topic, user)
    other_user = confirmed_user_fixture()
    {:ok, _} = Topics.create_subscription(topic, other_user)

    for subscriber <- [user, other_user] do
      {:ok, _} = Forums.create_subscription(forum, subscriber)
    end

    author = confirmed_user_fixture()
    {:ok, 2} = Notifications.broadcast_forum_post(author, topic, hd(topic.posts))
    {:ok, 2} = Notifications.broadcast_forum_topic(author, topic)
    moderator = moderator_user_fixture()

    {:ok, {_forum, topic}} =
      Topics.create_topic_hide(
        Philomena.AttributionFixtures.actor(moderator),
        forum.short_name,
        topic.slug,
        %{"deletion_reason" => "test hiding"}
      )

    conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/read")

    assert response(conn, 200) == ""

    for schema <- [ForumPostNotification, ForumTopicNotification] do
      refute Repo.exists?(from n in schema, where: n.user_id == ^user.id)
      assert Repo.exists?(from n in schema, where: n.user_id == ^other_user.id)
    end
  end
end
