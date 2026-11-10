defmodule PhilomenaWeb.Topic.SubscriptionControllerTest do
  use PhilomenaWeb.ConnCase, async: true
  use PhilomenaWeb.SingletonToggleTests

  import Ecto.Query
  import Philomena.ForumsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Repo
  alias Philomena.Topics

  # require_authenticated_user halts before the resource loads, so the ids in
  # this path need not exist.
  defp anonymous_path, do: ~p"/forums/dummy/topics/1/subscription"

  defp subscription_target(user) do
    forum = forum_fixture()
    topic = topic_fixture(forum)

    %{
      path: ~p"/forums/#{forum}/topics/#{topic}/subscription",
      subscribe!: fn -> {:ok, _} = Topics.create_subscription(topic, user) end,
      subscribed?: fn ->
        Repo.exists?(
          from s in Topics.Subscription,
            where: s.topic_id == ^topic.id and s.user_id == ^user.id
        )
      end
    }
  end

  subscription_toggle_tests()

  test "POST for an unknown forum redirects to / with the not-found flash",
       %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn = post(conn, ~p"/forums/nonexistent/topics/some-topic/subscription")

    assert redirected_to(conn) == "/"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "Couldn't find what you were looking for!"
  end

  test "POST for an unknown topic redirects to / with the not-found flash", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    forum = forum_fixture()

    conn = post(conn, ~p"/forums/#{forum}/topics/nonexistent-topic/subscription")

    assert redirected_to(conn) == "/"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "Couldn't find what you were looking for!"
  end

  test "a hidden topic cannot be subscribed to but can be unsubscribed from",
       %{conn: conn} do
    # NOTE: the context's show_forum_topic passes show_hidden: true for
    # unsubscribe (:delete) only, so the two actions diverge on hidden topics
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    forum = forum_fixture()
    topic = topic_fixture(forum)
    {:ok, _} = Topics.create_subscription(topic, user)
    moderator = moderator_user_fixture()

    {:ok, {_forum, topic}} =
      Topics.create_topic_hide(
        Philomena.AttributionFixtures.actor(moderator),
        forum.short_name,
        topic.slug,
        %{"deletion_reason" => "test hiding"}
      )

    conn2 = post(conn, ~p"/forums/#{forum}/topics/#{topic}/subscription")
    assert redirected_to(conn2) == "/"
    assert Phoenix.Flash.get(conn2.assigns.flash, :error) == "You can't access that page."

    conn3 = delete(conn, ~p"/forums/#{forum}/topics/#{topic}/subscription")
    refute PhilomenaWeb.SingletonToggleTests.subscription_partial_watching?(conn3)
  end
end
