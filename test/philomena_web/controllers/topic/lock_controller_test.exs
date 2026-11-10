defmodule PhilomenaWeb.Topic.LockControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ForumsFixtures
  import Philomena.TopicsFixtures

  alias Philomena.Repo

  setup do
    forum = forum_fixture()
    topic = topic_fixture(forum)

    %{forum: forum, topic: topic}
  end

  describe "POST /forums/:forum_id/topics/:topic_id/lock" do
    test "redirects anonymous users to the login page", %{conn: conn, forum: forum, topic: topic} do
      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/lock", %{
          "topic" => %{"lock_reason" => "Off topic"}
        })

      assert redirected_to(conn) == ~p"/sessions/new"
      assert Repo.reload!(topic).locked_at == nil
    end

    test "rejects a regular user with the authorization flash",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/lock", %{
          "topic" => %{"lock_reason" => "Off topic"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(topic).locked_at == nil
    end

    test "as a moderator locks the topic and records the reason and locker",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn, user: user} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/lock", %{
          "topic" => %{"lock_reason" => "Off topic"}
        })

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Topic successfully locked!"

      topic = Repo.reload!(topic)
      assert topic.locked_at != nil
      assert topic.lock_reason == "Off topic"
      assert topic.locked_by_id == user.id
    end

    # Failure path: lock_changeset requires lock_reason, so a blank reason takes
    # the {:error, _changeset} branch and redirects with the error flash.
    test "with a blank lock reason redirects with the error flash",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/lock", %{
          "topic" => %{"lock_reason" => ""}
        })

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Unable to lock the topic!"
      assert Repo.reload!(topic).locked_at == nil
    end
  end

  describe "DELETE /forums/:forum_id/topics/:topic_id/lock" do
    setup %{forum: forum, topic: topic} do
      moderator = Philomena.UsersFixtures.moderator_user_fixture()

      {:ok, {_forum, topic}} =
        Philomena.Topics.create_topic_lock(
          Philomena.AttributionFixtures.actor(moderator),
          forum.short_name,
          topic.slug,
          %{"lock_reason" => "Off topic"}
        )

      %{topic: topic}
    end

    test "redirects anonymous users to the login page", %{conn: conn, forum: forum, topic: topic} do
      conn = delete(conn, ~p"/forums/#{forum}/topics/#{topic}/lock")

      assert redirected_to(conn) == ~p"/sessions/new"
      assert Repo.reload!(topic).locked_at != nil
    end

    test "rejects a regular user with the authorization flash",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = delete(conn, ~p"/forums/#{forum}/topics/#{topic}/lock")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(topic).locked_at != nil
    end

    test "as a moderator unlocks the topic", %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = delete(conn, ~p"/forums/#{forum}/topics/#{topic}/lock")

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Topic successfully unlocked!"

      topic = Repo.reload!(topic)
      assert topic.locked_at == nil
      assert topic.locked_by_id == nil
      assert topic.lock_reason == ""
    end
  end
end
