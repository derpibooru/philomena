defmodule Philomena.PollVotesTest do
  @moduledoc """
  Context-level tests for the actor-first `Philomena.PollVotes` API:
  `list_votes/3`, `create_votes/4`, and `delete_vote/4`.

  These pin the shared load-and-authorize chain the vote routes reuse (forum
  `:show`, topic visibility, poll existence) and where each function diverges
  from it: `list_votes/3` and `delete_vote/4` additionally gate on the topic
  `:hide` permission, while `create_votes/4` runs `verify_write_access/1` first
  (before any loading) and never checks `:hide`. The corresponding controller
  characterization tests pin the HTTP behavior on top of these results.
  """

  use Philomena.DataCase, async: true

  import Ecto.Query

  import Philomena.AttributionFixtures
  import Philomena.ForumsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.PollVotes
  alias Philomena.PollVotes.PollVote
  alias Philomena.Repo

  # A truthy ban value in the shape production passes (the result of
  # Philomena.Bans.find/3); only its presence matters to verify_write_access.
  @ban %{
    reason: "Rule #0",
    valid_until: ~U[3000-01-01 00:00:00Z],
    generated_ban_id: "U123456",
    type: "User"
  }

  # A visible topic (in a normal, publicly readable forum) carrying a two-option
  # poll, with the options preloaded and sorted by label. This is the common
  # shape all three functions load through.
  defp forum_topic_poll_options do
    forum = forum_fixture()
    {topic, poll} = topic_with_poll_fixture(forum)
    poll = Repo.preload(poll, :options)
    [option_a, option_b] = Enum.sort_by(poll.options, & &1.label)

    %{forum: forum, topic: topic, poll: poll, option_a: option_a, option_b: option_b}
  end

  # Records a vote for `option` by a fresh confirmed voter through the engine,
  # returning the persisted PollVote row.
  defp record_vote(forum, topic, option) do
    voter = confirmed_user_fixture()

    {:ok, _ballot} =
      PollVotes.create_votes(actor(voter), forum.short_name, topic.slug, %{
        "option_ids" => [to_string(option.id)]
      })

    Repo.one!(
      from pv in PollVote,
        where: pv.poll_option_id == ^option.id and pv.user_id == ^voter.id
    )
  end

  describe "list_votes/3" do
    test "a regular user is unauthorized even though the poll exists" do
      # The topic is visible, so the forum :show and topic visibility checks pass
      # and the poll load succeeds; the block on the topic :hide permission is
      # what denies a regular user.
      user = confirmed_user_fixture()
      %{forum: forum, topic: topic} = forum_topic_poll_options()

      assert PollVotes.list_votes(actor(user), forum.short_name, topic.slug) ==
               {:error, :unauthorized}
    end

    test "a moderator gets only options with votes, with voters preloaded" do
      moderator = moderator_user_fixture()

      %{forum: forum, topic: topic, option_a: option_a, option_b: option_b} =
        forum_topic_poll_options()

      vote = record_vote(forum, topic, option_a)

      assert {:ok, [option]} =
               PollVotes.list_votes(actor(moderator), forum.short_name, topic.slug)

      # Only the option that carries a vote is returned; the zero-vote option is
      # dropped so the index view renders only options someone voted for.
      assert option.id == option_a.id
      refute option.id == option_b.id

      # The votes and their voters are preloaded (a loaded list of PollVote rows,
      # each with a loaded %User{}), not unloaded associations.
      assert [%PollVote{} = loaded_vote] = option.poll_votes
      assert loaded_vote.id == vote.id
      assert %Philomena.Users.User{} = loaded_vote.user
    end

    test "an unknown forum is not found" do
      assert PollVotes.list_votes(actor(moderator_user_fixture()), "nonexistent", "whatever") ==
               {:error, :not_found}
    end

    test "an existing forum with an unknown topic is not found" do
      forum = forum_fixture()

      assert PollVotes.list_votes(
               actor(moderator_user_fixture()),
               forum.short_name,
               "nonexistent-topic"
             ) ==
               {:error, :not_found}
    end

    test "a topic without a poll is not found for a moderator" do
      # A topic that carries no poll is not_found, and this check runs before
      # the :hide authorization.
      forum = forum_fixture()
      topic = topic_fixture(forum)

      assert PollVotes.list_votes(actor(moderator_user_fixture()), forum.short_name, topic.slug) ==
               {:error, :not_found}
    end
  end

  describe "create_votes/4" do
    test "a banned actor is rejected before any loading" do
      # verify_write_access runs first, so a banned actor is {:error, :ban} even
      # against a forum slug that does not exist: had loading run first, a missing
      # forum would surface as :unauthorized. Getting :ban pins that the ban check
      # precedes the forum/topic/poll load.
      actor = actor(confirmed_user_fixture(), ban: @ban)

      assert PollVotes.create_votes(actor, "nonexistent", "whatever", %{"option_ids" => ["1"]}) ==
               {:error, :ban}
    end

    test "an actor with no fingerprint is unauthorized before any loading, signed in or not" do
      # The fingerprint requirement applies regardless of whether a user is signed
      # in, and (like the ban check) precedes loading, so a missing forum still
      # answers unauthorized from the write-access gate rather than the loader.
      signed_in = actor(confirmed_user_fixture(), fingerprint: nil)
      anonymous = actor(nil, fingerprint: nil)

      assert PollVotes.create_votes(signed_in, "nonexistent", "whatever", %{
               "option_ids" => ["1"]
             }) == {:error, :unauthorized}

      assert PollVotes.create_votes(anonymous, "nonexistent", "whatever", %{
               "option_ids" => ["1"]
             }) == {:error, :unauthorized}
    end

    test "a valid signed-in actor records the vote" do
      user = confirmed_user_fixture()
      %{forum: forum, topic: topic, poll: poll, option_a: option_a} = forum_topic_poll_options()

      assert {:ok, ballot} =
               PollVotes.create_votes(actor(user), forum.short_name, topic.slug, %{
                 "option_ids" => [to_string(option_a.id)]
               })

      assert ballot.poll.id == poll.id

      assert Repo.exists?(
               from pv in PollVote,
                 where: pv.poll_option_id == ^option_a.id and pv.user_id == ^user.id
             )

      assert Repo.reload!(option_a).vote_count == 1
      assert Repo.reload!(poll).total_votes == 1
    end

    test "an empty poll parameter records nothing and reports failure with the topic" do
      user = confirmed_user_fixture()
      %{forum: forum, topic: topic, poll: poll} = forum_topic_poll_options()

      assert {:error, %Ecto.Changeset{data: ballot} = changeset} =
               PollVotes.create_votes(actor(user), forum.short_name, topic.slug, %{})

      assert ballot.poll.id == poll.id
      assert %{option_ids: ["must select a choice"]} = errors_on(changeset)
      assert Repo.aggregate(PollVote, :count) == 0
    end

    test "duplicate choices reject the entire selection" do
      user = confirmed_user_fixture()
      %{forum: forum, topic: topic, option_a: option} = forum_topic_poll_options()
      option_id = to_string(option.id)

      assert {:error, changeset} =
               PollVotes.create_votes(actor(user), forum.short_name, topic.slug, %{
                 "option_ids" => [option_id, option_id]
               })

      assert %{option_ids: ["contains duplicate choices"]} = errors_on(changeset)
      assert Repo.aggregate(PollVote, :count) == 0
    end

    test "malformed and wrong-poll choices reject the entire selection" do
      user = confirmed_user_fixture()

      %{forum: forum, topic: topic, option_a: valid_option} = forum_topic_poll_options()
      %{option_a: wrong_option} = forum_topic_poll_options()

      for option_ids <- [
            [to_string(wrong_option.id)],
            [to_string(valid_option.id), to_string(wrong_option.id)]
          ] do
        assert {:error, changeset} =
                 PollVotes.create_votes(actor(user), forum.short_name, topic.slug, %{
                   "option_ids" => option_ids
                 })

        assert %{option_ids: ["contains an invalid choice"]} = errors_on(changeset)
      end

      assert {:error, changeset} =
               PollVotes.create_votes(actor(user), forum.short_name, topic.slug, %{
                 "option_ids" => ["not-an-id"]
               })

      assert %{option_ids: ["is invalid"]} = errors_on(changeset)

      assert Repo.aggregate(PollVote, :count) == 0
    end

    test "a single-choice poll rejects multiple distinct choices" do
      user = confirmed_user_fixture()

      %{forum: forum, topic: topic, option_a: option_a, option_b: option_b} =
        forum_topic_poll_options()

      assert {:error, changeset} =
               PollVotes.create_votes(actor(user), forum.short_name, topic.slug, %{
                 "option_ids" => [to_string(option_a.id), to_string(option_b.id)]
               })

      assert %{option_ids: ["must select exactly one choice"]} = errors_on(changeset)
      assert Repo.aggregate(PollVote, :count) == 0
    end

    test "an expired poll is rejected" do
      # The engine's :ended step bails when the poll is no longer active, so a
      # closed poll surfaces as {:error, forum, topic} (both carried so the
      # controller can redirect back) with nothing recorded.
      user = confirmed_user_fixture()
      %{forum: forum, topic: topic, poll: poll, option_a: option_a} = forum_topic_poll_options()

      poll
      |> Ecto.Changeset.change(active_until: DateTime.add(DateTime.utc_now(:second), -1, :day))
      |> Repo.update!()

      assert {:error, %Ecto.Changeset{data: ballot} = changeset} =
               PollVotes.create_votes(actor(user), forum.short_name, topic.slug, %{
                 "option_ids" => [to_string(option_a.id)]
               })

      assert ballot.poll.id == poll.id
      assert %{option_ids: ["poll is closed"]} = errors_on(changeset)
      assert Repo.aggregate(PollVote, :count) == 0
    end

    test "a multiple-choice poll accepts one or more choices" do
      user = confirmed_user_fixture()
      forum = forum_fixture()
      {topic, poll} = topic_with_poll_fixture(forum, nil, %{"vote_method" => "multiple"})
      [option_a | _options] = poll |> Repo.preload(:options) |> Map.fetch!(:options)

      assert {:ok, _ballot} =
               PollVotes.create_votes(actor(user), forum.short_name, topic.slug, %{
                 "option_ids" => [to_string(option_a.id)]
               })

      assert Repo.aggregate(PollVote, :count) == 1
    end

    test "a repeat vote by the same user is rejected" do
      user = confirmed_user_fixture()

      %{forum: forum, topic: topic, poll: poll, option_a: option_a, option_b: option_b} =
        forum_topic_poll_options()

      assert {:ok, _ballot} =
               PollVotes.create_votes(actor(user), forum.short_name, topic.slug, %{
                 "option_ids" => [to_string(option_a.id)]
               })

      assert {:error, %Ecto.Changeset{data: ballot} = changeset} =
               PollVotes.create_votes(actor(user), forum.short_name, topic.slug, %{
                 "option_ids" => [to_string(option_b.id)]
               })

      assert ballot.poll.id == poll.id
      assert %{option_ids: ["has already voted"]} = errors_on(changeset)
      assert Repo.aggregate(from(pv in PollVote, where: pv.user_id == ^user.id), :count) == 1
    end

    test "an anonymous but fingerprinted actor is unauthorized" do
      %{forum: forum, topic: topic, option_a: option_a} = forum_topic_poll_options()

      assert PollVotes.create_votes(actor(nil), forum.short_name, topic.slug, %{
               "option_ids" => [to_string(option_a.id)]
             }) == {:error, :unauthorized}

      assert Repo.aggregate(PollVote, :count) == 0
    end
  end

  describe "delete_vote/4" do
    test "a regular user is unauthorized and the vote survives" do
      # The :hide check runs before the vote is even looked up, so a regular user
      # is denied regardless of the vote id.
      user = confirmed_user_fixture()
      %{forum: forum, topic: topic, option_a: option_a} = forum_topic_poll_options()
      vote = record_vote(forum, topic, option_a)

      assert PollVotes.delete_vote(actor(user), forum.short_name, topic.slug, to_string(vote.id)) ==
               {:error, :unauthorized}

      assert Repo.get(PollVote, vote.id)
    end

    test "a moderator with an unknown vote id gets not-found" do
      moderator = moderator_user_fixture()
      %{forum: forum, topic: topic} = forum_topic_poll_options()

      assert PollVotes.delete_vote(
               actor(moderator),
               forum.short_name,
               topic.slug,
               "999999999"
             ) == {:error, :not_found}
    end

    test "a moderator with a non-integer vote id gets not-found" do
      # The id is parsed with IntegerId first, so an unparsable id takes the same
      # nil path as an unknown one rather than raising.
      moderator = moderator_user_fixture()
      %{forum: forum, topic: topic} = forum_topic_poll_options()

      assert PollVotes.delete_vote(
               actor(moderator),
               forum.short_name,
               topic.slug,
               "not-a-number"
             ) == {:error, :not_found}
    end

    test "a vote from another poll is not found and survives" do
      moderator = moderator_user_fixture()
      %{forum: forum, topic: topic} = forum_topic_poll_options()

      %{
        forum: other_forum,
        topic: other_topic,
        poll: other_poll,
        option_a: other_option
      } = forum_topic_poll_options()

      other_vote = record_vote(other_forum, other_topic, other_option)

      assert PollVotes.delete_vote(
               actor(moderator),
               forum.short_name,
               topic.slug,
               to_string(other_vote.id)
             ) == {:error, :not_found}

      assert Repo.get(PollVote, other_vote.id)
      assert Repo.reload!(other_option).vote_count == 1
      assert Repo.reload!(other_poll).total_votes == 1
    end

    test "a moderator removes the vote and decrements the cached tallies" do
      moderator = moderator_user_fixture()
      %{forum: forum, topic: topic, poll: poll, option_a: option_a} = forum_topic_poll_options()
      vote = record_vote(forum, topic, option_a)

      assert Repo.reload!(option_a).vote_count == 1
      assert Repo.reload!(poll).total_votes == 1

      assert {:ok, poll} =
               PollVotes.delete_vote(
                 actor(moderator),
                 forum.short_name,
                 topic.slug,
                 to_string(vote.id)
               )

      assert poll.topic.id == topic.id
      assert poll.topic.forum.id == forum.id
      refute Repo.get(PollVote, vote.id)

      assert Repo.reload!(option_a).vote_count == 0
      assert Repo.reload!(poll).total_votes == 0
    end
  end
end
