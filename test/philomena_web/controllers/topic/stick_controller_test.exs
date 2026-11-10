defmodule PhilomenaWeb.Topic.StickControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ForumsFixtures
  import Philomena.TopicsFixtures

  alias Philomena.Repo

  setup do
    forum = forum_fixture()
    topic = topic_fixture(forum)

    %{forum: forum, topic: topic}
  end

  describe "POST /forums/:forum_id/topics/:topic_id/stick" do
    test "redirects anonymous users to the login page", %{conn: conn, forum: forum, topic: topic} do
      conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/stick")

      assert redirected_to(conn) == ~p"/sessions/new"
      refute Repo.reload!(topic).sticky
    end

    test "rejects a regular user with the authorization flash",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/stick")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.reload!(topic).sticky
    end

    test "as a moderator sticks the topic", %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/stick")

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Topic successfully stickied!"
      assert Repo.reload!(topic).sticky
    end

    # Failure path: stick_changeset never fails, so the only reachable failure
    # surface is an unknown topic - the context's show_forum_topic returns
    # not_found and redirects to /.
    test "redirects to / with the not-found flash for an unknown topic",
         %{conn: conn, forum: forum} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/forums/#{forum}/topics/nonexistent-topic/stick")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end
  end

  describe "DELETE /forums/:forum_id/topics/:topic_id/stick" do
    setup %{forum: forum, topic: topic} do
      moderator = Philomena.UsersFixtures.moderator_user_fixture()

      {:ok, {_forum, topic}} =
        Philomena.Topics.create_topic_stick(
          Philomena.AttributionFixtures.actor(moderator),
          forum.short_name,
          topic.slug
        )

      %{topic: topic}
    end

    test "redirects anonymous users to the login page", %{conn: conn, forum: forum, topic: topic} do
      conn = delete(conn, ~p"/forums/#{forum}/topics/#{topic}/stick")

      assert redirected_to(conn) == ~p"/sessions/new"
      assert Repo.reload!(topic).sticky
    end

    test "rejects a regular user with the authorization flash",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = delete(conn, ~p"/forums/#{forum}/topics/#{topic}/stick")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(topic).sticky
    end

    test "as a moderator unsticks the topic", %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = delete(conn, ~p"/forums/#{forum}/topics/#{topic}/stick")

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Topic successfully unstickied!"
      refute Repo.reload!(topic).sticky
    end

    # Unsticking an already-unstuck topic still succeeds (the changeset sets the
    # column unconditionally).
    test "unsticking a non-sticky topic still succeeds", %{conn: conn, forum: forum} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      topic = topic_fixture(forum)

      conn = delete(conn, ~p"/forums/#{forum}/topics/#{topic}/stick")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Topic successfully unstickied!"
      refute Repo.reload!(topic).sticky
    end
  end
end
