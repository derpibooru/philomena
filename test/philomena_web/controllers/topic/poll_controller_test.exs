defmodule PhilomenaWeb.Topic.PollControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Ecto.Query
  import Philomena.ForumsFixtures
  import Philomena.TopicsFixtures

  alias Philomena.Polls.Poll
  alias Philomena.Repo

  setup do
    forum = forum_fixture()

    topic =
      topic_fixture(forum, nil, %{
        "poll" => %{
          "title" => "Best test option?",
          "active_until" => DateTime.add(DateTime.utc_now(:second), 7, :day),
          "vote_method" => "single",
          "options" => %{"0" => %{"label" => "Option A"}, "1" => %{"label" => "Option B"}}
        }
      })

    poll = Repo.one!(from p in Poll, where: p.topic_id == ^topic.id)

    %{forum: forum, topic: topic, poll: poll}
  end

  describe "GET /forums/:forum_id/topics/:topic_id/poll/edit" do
    test "redirects anonymous users to the login page", %{conn: conn, forum: forum, topic: topic} do
      conn = get(conn, ~p"/forums/#{forum}/topics/#{topic}/poll/edit")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "rejects a regular user with the authorization flash",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/forums/#{forum}/topics/#{topic}/poll/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    # The context loads the topic (show_hidden: false) and authorizes :hide of
    # the topic, both moderator capabilities - so a moderator renders the poll
    # edit form even though the route action is :edit.
    test "renders the edit form for a moderator", %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      response = html_response(get(conn, ~p"/forums/#{forum}/topics/#{topic}/poll/edit"), 200)

      assert response =~ "Editing Poll - Derpibooru"
    end

    test "renders the edit form for an admin", %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      response = html_response(get(conn, ~p"/forums/#{forum}/topics/#{topic}/poll/edit"), 200)

      assert response =~ "Editing Poll - Derpibooru"
    end

    test "redirects to / with the not-found flash when the topic has no poll",
         %{conn: conn, forum: forum} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      plain_topic = topic_fixture(forum)

      conn = get(conn, ~p"/forums/#{forum}/topics/#{plain_topic}/poll/edit")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "renders the edit form for a moderator without a fingerprint",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(without_fingerprint(conn), ~p"/forums/#{forum}/topics/#{topic}/poll/edit")

      assert html_response(conn, 200) =~ "Editing Poll - Derpibooru"
    end
  end

  describe "PATCH /forums/:forum_id/topics/:topic_id/poll" do
    test "redirects anonymous users to the login page", %{conn: conn, forum: forum, topic: topic} do
      conn =
        patch(conn, ~p"/forums/#{forum}/topics/#{topic}/poll", %{
          "poll" => %{"title" => "New title"}
        })

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "rejects a regular user with the authorization flash",
         %{conn: conn, forum: forum, topic: topic, poll: poll} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn =
        patch(conn, ~p"/forums/#{forum}/topics/#{topic}/poll", %{
          "poll" => %{"title" => "New title"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(poll).title == "Best test option?"
    end

    # See the :edit note above - update is also mapped to :show, so moderators
    # can now update the poll.
    test "as a moderator updates the poll and redirects to the topic",
         %{conn: conn, forum: forum, topic: topic, poll: poll} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(conn, ~p"/forums/#{forum}/topics/#{topic}/poll", %{
          "poll" => %{
            "title" => "Moderator updated title",
            "active_until" =>
              DateTime.utc_now(:second) |> DateTime.add(3, :day) |> DateTime.to_iso8601(),
            "vote_method" => "single"
          }
        })

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Poll successfully updated."
      assert Repo.reload!(poll).title == "Moderator updated title"
    end

    test "as an admin updates the poll and redirects to the topic",
         %{conn: conn, forum: forum, topic: topic, poll: poll} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        patch(conn, ~p"/forums/#{forum}/topics/#{topic}/poll", %{
          "poll" => %{
            "title" => "Updated poll title",
            "active_until" =>
              DateTime.utc_now(:second) |> DateTime.add(3, :day) |> DateTime.to_iso8601(),
            "vote_method" => "single"
          }
        })

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Poll successfully updated."
      assert Repo.reload!(poll).title == "Updated poll title"
    end

    test "PUT also updates the poll", %{conn: conn, forum: forum, topic: topic, poll: poll} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        put(conn, ~p"/forums/#{forum}/topics/#{topic}/poll", %{
          "poll" => %{
            "title" => "Updated via PUT",
            "active_until" =>
              DateTime.utc_now(:second) |> DateTime.add(3, :day) |> DateTime.to_iso8601(),
            "vote_method" => "single"
          }
        })

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Repo.reload!(poll).title == "Updated via PUT"
    end

    # Failure path: Poll.changeset validate_requires title/active_until/
    # vote_method, so a blank title re-renders edit.html (200).
    test "re-renders the form when the title is blank",
         %{conn: conn, forum: forum, topic: topic, poll: poll} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        patch(conn, ~p"/forums/#{forum}/topics/#{topic}/poll", %{
          "poll" => %{
            "title" => "",
            "active_until" =>
              DateTime.utc_now(:second) |> DateTime.add(3, :day) |> DateTime.to_iso8601(),
            "vote_method" => "single"
          }
        })

      assert html_response(conn, 200) =~ "Editing Poll"
      assert Repo.reload!(poll).title == "Best test option?"
    end

    test "without a fingerprint redirects to / with the authorization flash",
         %{conn: conn, forum: forum, topic: topic, poll: poll} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(without_fingerprint(conn), ~p"/forums/#{forum}/topics/#{topic}/poll", %{
          "poll" => %{"title" => "Moderator updated title"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(poll).title == poll.title
    end
  end
end
