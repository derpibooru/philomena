defmodule PhilomenaWeb.Topic.HideControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ForumsFixtures
  import Philomena.TopicsFixtures

  alias Philomena.Topics
  alias Philomena.Repo

  setup do
    forum = forum_fixture()
    topic = topic_fixture(forum)

    %{forum: forum, topic: topic}
  end

  defp hidden_topic(forum, topic) do
    moderator = Philomena.UsersFixtures.moderator_user_fixture()

    {:ok, {_forum, topic}} =
      Topics.create_topic_hide(
        Philomena.AttributionFixtures.actor(moderator),
        forum.short_name,
        topic.slug,
        %{"deletion_reason" => "Spam"}
      )

    topic
  end

  describe "POST /forums/:forum_id/topics/:topic_id/hide" do
    test "redirects anonymous users to the login page", %{conn: conn, forum: forum, topic: topic} do
      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/hide", %{
          "topic" => %{"deletion_reason" => "Spam"}
        })

      assert redirected_to(conn) == ~p"/sessions/new"
      refute Repo.reload!(topic).hidden_from_users
    end

    test "rejects a regular user with the authorization flash",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/hide", %{
          "topic" => %{"deletion_reason" => "Spam"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.reload!(topic).hidden_from_users
    end

    test "as a moderator hides the topic and records the reason and deleter",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn, user: user} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/hide", %{
          "topic" => %{"deletion_reason" => "Rule violation"}
        })

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Topic successfully deleted!"

      topic = Repo.reload!(topic)
      assert topic.hidden_from_users
      assert topic.deletion_reason == "Rule violation"
      assert topic.deleted_by_id == user.id
    end

    # Failure path: hide_changeset requires deletion_reason. create_topic_hide now
    # normalizes its Multi failure to {:error, changeset}, so a blank reason
    # redirects back with the "Unable to delete the topic!" flash instead of
    # raising CaseClauseError.
    test "with a blank deletion reason redirects back with the failure flash",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/hide", %{
          "topic" => %{"deletion_reason" => ""}
        })

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Unable to delete the topic!"

      refute Repo.reload!(topic).hidden_from_users
    end

    test "redirects to / with the not-found flash for an unknown topic",
         %{conn: conn, forum: forum} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/nonexistent-topic/hide", %{
          "topic" => %{"deletion_reason" => "Spam"}
        })

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end
  end

  describe "DELETE /forums/:forum_id/topics/:topic_id/hide" do
    test "redirects anonymous users to the login page", %{conn: conn, forum: forum, topic: topic} do
      topic = hidden_topic(forum, topic)

      conn = delete(conn, ~p"/forums/#{forum}/topics/#{topic}/hide")

      assert redirected_to(conn) == ~p"/sessions/new"
      assert Repo.reload!(topic).hidden_from_users
    end

    # A regular user cannot even load a hidden topic - the context's topic load
    # rejects it (show_hidden: false) before the :hide authorization, so the
    # not-authorized result comes from the load-visibility step.
    test "rejects a regular user with the authorization flash",
         %{conn: conn, forum: forum, topic: topic} do
      topic = hidden_topic(forum, topic)
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = delete(conn, ~p"/forums/#{forum}/topics/#{topic}/hide")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(topic).hidden_from_users
    end

    test "as a moderator restores the topic", %{conn: conn, forum: forum, topic: topic} do
      topic = hidden_topic(forum, topic)
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = delete(conn, ~p"/forums/#{forum}/topics/#{topic}/hide")

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Topic successfully restored!"

      topic = Repo.reload!(topic)
      refute topic.hidden_from_users
      assert topic.deleted_by_id == nil
      assert topic.deletion_reason == ""
    end
  end
end
