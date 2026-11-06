defmodule PhilomenaWeb.Topic.Poll.VoteControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # :create is public (any logged-in user); :index and :delete are
  # moderator-only (the context authorizes :hide of the topic).

  import Ecto.Query
  import Philomena.ForumsFixtures
  import Philomena.TopicsFixtures

  alias Philomena.PollVotes
  alias Philomena.Polls.Poll
  alias Philomena.PollVotes.PollVote
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

    poll = Repo.one!(from p in Poll, where: p.topic_id == ^topic.id) |> Repo.preload(:options)
    [option_a, option_b] = Enum.sort_by(poll.options, & &1.label)

    %{forum: forum, topic: topic, poll: poll, option_a: option_a, option_b: option_b}
  end

  describe "POST /forums/:forum_id/topics/:topic_id/poll/votes" do
    test "redirects anonymous users to the login page",
         %{conn: conn, forum: forum, topic: topic} do
      conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/poll/votes", %{})

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "records the vote and redirects to the topic",
         %{conn: conn, forum: forum, topic: topic, poll: poll, option_a: option_a} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/poll/votes", %{
          "poll" => %{"option_ids" => [to_string(option_a.id)]}
        })

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Your vote has been recorded."

      assert Repo.exists?(
               from pv in PollVote,
                 where: pv.poll_option_id == ^option_a.id and pv.user_id == ^user.id
             )

      assert Repo.reload!(option_a).vote_count == 1
      assert Repo.reload!(poll).total_votes == 1
    end

    test "rejects multiple options on a single-vote poll",
         %{conn: conn, forum: forum, topic: topic, option_a: option_a, option_b: option_b} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/poll/votes", %{
          "poll" => %{"option_ids" => [to_string(option_a.id), to_string(option_b.id)]}
        })

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Your vote was not recorded."
      assert Repo.aggregate(PollVote, :count) == 0
    end

    test "rejects a submission with no option selected",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/poll/votes", %{})

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Your vote was not recorded."
      assert Repo.aggregate(PollVote, :count) == 0
    end

    test "does not record a second vote by the same user",
         %{conn: conn, forum: forum, topic: topic, option_a: option_a, option_b: option_b} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      post(conn, ~p"/forums/#{forum}/topics/#{topic}/poll/votes", %{
        "poll" => %{"option_ids" => [to_string(option_a.id)]}
      })

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/poll/votes", %{
          "poll" => %{"option_ids" => [to_string(option_b.id)]}
        })

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Your vote was not recorded."
      assert Repo.aggregate(from(pv in PollVote, where: pv.user_id == ^user.id), :count) == 1
    end

    test "does not record a vote on an expired poll",
         %{conn: conn, forum: forum, topic: topic, poll: poll, option_a: option_a} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      poll
      |> Ecto.Changeset.change(active_until: DateTime.add(DateTime.utc_now(:second), -1, :day))
      |> Repo.update!()

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/poll/votes", %{
          "poll" => %{"option_ids" => [to_string(option_a.id)]}
        })

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Your vote was not recorded."
      assert Repo.aggregate(PollVote, :count) == 0
    end

    test "drops a non-integer option id",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/poll/votes", %{
          "poll" => %{"option_ids" => ["not-a-number"]}
        })

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Repo.aggregate(from(pv in PollVote, where: pv.user_id == ^user.id), :count) == 0
    end

    test "does not record a vote for an option belonging to a different poll",
         %{conn: conn, forum: forum, topic: topic} do
      # filter_options now restricts the submitted option ids to those that
      # actually belong to the poll being voted on, so an option id from a
      # foreign poll is dropped and never counted.
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      other_topic =
        topic_fixture(forum, nil, %{
          "poll" => %{
            "title" => "Other poll?",
            "active_until" => DateTime.add(DateTime.utc_now(:second), 7, :day),
            "vote_method" => "single",
            "options" => %{"0" => %{"label" => "Other A"}, "1" => %{"label" => "Other B"}}
          }
        })

      other_poll =
        Repo.one!(from p in Poll, where: p.topic_id == ^other_topic.id)
        |> Repo.preload(:options)

      foreign_option = hd(other_poll.options)

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/poll/votes", %{
          "poll" => %{"option_ids" => [to_string(foreign_option.id)]}
        })

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"

      refute Repo.exists?(
               from pv in PollVote,
                 where: pv.poll_option_id == ^foreign_option.id and pv.user_id == ^user.id
             )

      assert Repo.reload!(foreign_option).vote_count == 0
    end

    test "redirects to / with the not-found flash when the topic has no poll",
         %{conn: conn, forum: forum} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      plain_topic = topic_fixture(forum)

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{plain_topic}/poll/votes", %{
          "poll" => %{"option_ids" => ["1"]}
        })

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "redirects banned users with the ban flash",
         %{conn: conn, forum: forum, topic: topic, option_a: option_a} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/poll/votes", %{
          "poll" => %{"option_ids" => [to_string(option_a.id)]}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
      assert Repo.aggregate(PollVote, :count) == 0
    end
  end

  # Records a vote for `option` by a fresh voter and returns the PollVote row.
  defp record_vote(forum, topic, option) do
    voter = Philomena.UsersFixtures.confirmed_user_fixture()
    actor = Philomena.AttributionFixtures.actor(voter)

    {:ok, _ballot} =
      PollVotes.create_votes(actor, forum.short_name, topic.slug, %{option_ids: [option.id]})

    Repo.one!(
      from pv in PollVote, where: pv.poll_option_id == ^option.id and pv.user_id == ^voter.id
    )
    |> Repo.preload(:user)
  end

  describe "GET /forums/:forum_id/topics/:topic_id/poll/votes" do
    test "redirects anonymous users to the login page", %{conn: conn, forum: forum, topic: topic} do
      conn = get(conn, ~p"/forums/#{forum}/topics/#{topic}/poll/votes")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "rejects a regular user with the authorization flash",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/forums/#{forum}/topics/#{topic}/poll/votes")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "as a moderator lists the voters for options with votes",
         %{conn: conn, forum: forum, topic: topic, option_a: option_a} do
      vote = record_vote(forum, topic, option_a)
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      response = html_response(get(conn, ~p"/forums/#{forum}/topics/#{topic}/poll/votes"), 200)

      assert response =~ option_a.label
      assert response =~ vote.user.name
    end

    # Empty case: the controller filters to options with vote_count > 0, so a
    # poll with no votes renders the "no votes" branch.
    test "as a moderator renders the empty branch when there are no votes",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      response = html_response(get(conn, ~p"/forums/#{forum}/topics/#{topic}/poll/votes"), 200)

      assert response =~ "No votes to display"
    end

    test "redirects to / with the not-found flash when the topic has no poll",
         %{conn: conn, forum: forum} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      plain_topic = topic_fixture(forum)

      conn = get(conn, ~p"/forums/#{forum}/topics/#{plain_topic}/poll/votes")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end
  end

  describe "DELETE /forums/:forum_id/topics/:topic_id/poll/votes/:id" do
    test "redirects anonymous users to the login page",
         %{conn: conn, forum: forum, topic: topic, option_a: option_a} do
      vote = record_vote(forum, topic, option_a)

      conn = delete(conn, ~p"/forums/#{forum}/topics/#{topic}/poll/votes/#{vote}")

      assert redirected_to(conn) == ~p"/sessions/new"
      assert Repo.get(PollVote, vote.id)
    end

    test "rejects a regular user with the authorization flash",
         %{conn: conn, forum: forum, topic: topic, option_a: option_a} do
      vote = record_vote(forum, topic, option_a)
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = delete(conn, ~p"/forums/#{forum}/topics/#{topic}/poll/votes/#{vote}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get(PollVote, vote.id)
    end

    test "as a moderator removes the vote row and decrements the cached tallies",
         %{conn: conn, forum: forum, topic: topic, poll: poll, option_a: option_a} do
      vote = record_vote(forum, topic, option_a)
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = delete(conn, ~p"/forums/#{forum}/topics/#{topic}/poll/votes/#{vote}")

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Vote successfully removed."
      refute Repo.get(PollVote, vote.id)

      # delete_poll_vote/1 now runs a Multi that deletes the row and decrements
      # both the poll option's vote_count and the poll's total_votes by 1, so
      # the cached tallies fall back to zero.
      assert Repo.reload!(option_a).vote_count == 0
      assert Repo.reload!(poll).total_votes == 0
    end

    # NOTE: the vote is now loaded with get_poll_vote/1, so an unknown id
    # redirects back to the topic with the failure flash rather than raising.
    test "for an unknown vote id redirects with the not-found flash",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = delete(conn, ~p"/forums/#{forum}/topics/#{topic}/poll/votes/999999999")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    # NOTE: a non-integer id is parsed first (IntegerId.parse), so it takes the
    # same nil path and redirects back with the failure flash.
    test "for a non-integer vote id redirects with the not-found flash",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = delete(conn, ~p"/forums/#{forum}/topics/#{topic}/poll/votes/not-a-number")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end
  end
end
