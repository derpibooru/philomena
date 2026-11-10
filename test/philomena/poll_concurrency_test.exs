defmodule Philomena.PollConcurrencyTest do
  use Philomena.ConcurrentDataCase

  import Ecto.Query
  import Philomena.AttributionFixtures
  import Philomena.ForumsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.PollOptions.PollOption
  alias Philomena.PollVotes
  alias Philomena.PollVotes.PollVote
  alias Philomena.Polls
  alias Philomena.Polls.Poll
  alias Philomena.Repo

  defp poll_fixture do
    forum = forum_fixture()
    {topic, poll} = topic_with_poll_fixture(forum)
    poll = Repo.preload(poll, :options)
    [option_a, option_b] = Enum.sort_by(poll.options, & &1.label)

    %{forum: forum, topic: topic, poll: poll, option_a: option_a, option_b: option_b}
  end

  defp vote(actor, fixture, option) do
    PollVotes.create_votes(actor, fixture.forum.short_name, fixture.topic.slug, %{
      "option_ids" => [to_string(option.id)]
    })
  end

  defp assert_consistent_poll(fixture, expected_total) do
    poll = Repo.reload!(fixture.poll)
    options = Repo.all(from option in PollOption, where: option.poll_id == ^poll.id)

    assert poll.total_votes == expected_total

    assert Repo.aggregate(
             from(vote in PollVote,
               join: option in assoc(vote, :poll_option),
               where: option.poll_id == ^poll.id
             ),
             :count
           ) == expected_total

    for option <- options do
      assert option.vote_count ==
               Repo.aggregate(
                 from(vote in PollVote, where: vote.poll_option_id == ^option.id),
                 :count
               )
    end
  end

  test "concurrent ballots preserve poll and option counters" do
    fixture = poll_fixture()

    functions =
      for option <- Enum.take(Stream.cycle([fixture.option_a, fixture.option_b]), 8) do
        user = confirmed_user_fixture()

        fn -> vote(actor(user), fixture, option) end
      end

    results = concurrently(functions)

    assert Enum.all?(results, &match?({:ok, _}, &1))
    assert_consistent_poll(fixture, 8)
  end

  test "concurrent ballots by one user cast exactly one ballot" do
    fixture = poll_fixture()
    user = confirmed_user_fixture()

    results =
      concurrently(
        for option <- List.duplicate(fixture.option_a, 8) do
          fn -> vote(actor(user), fixture, option) end
        end
      )

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &match?({:error, %Ecto.Changeset{}}, &1)) == 7
    assert_consistent_poll(fixture, 1)
    assert Repo.aggregate(from(vote in PollVote, where: vote.user_id == ^user.id), :count) == 1
  end

  test "concurrent deletion of ballots preserves poll and option counters" do
    fixture = poll_fixture()
    moderator = actor(moderator_user_fixture())

    votes =
      for option <- [fixture.option_a, fixture.option_b, fixture.option_a, fixture.option_b] do
        user = confirmed_user_fixture()
        {:ok, _} = vote(actor(user), fixture, option)

        Repo.one!(
          from vote in PollVote,
            where: vote.user_id == ^user.id and vote.poll_option_id == ^option.id
        )
      end

    assert_consistent_poll(fixture, 4)

    results =
      concurrently(
        for poll_vote <- votes do
          fn ->
            PollVotes.delete_vote(
              moderator,
              fixture.forum.short_name,
              fixture.topic.slug,
              poll_vote.id
            )
          end
        end
      )

    assert Enum.all?(results, &match?({:ok, %Poll{}}, &1))
    assert_consistent_poll(fixture, 0)
  end

  test "concurrent moderators deleting the same ballot return one not-found" do
    fixture = poll_fixture()
    voter = confirmed_user_fixture()
    moderators = [moderator_user_fixture(), moderator_user_fixture()]
    {:ok, _} = vote(actor(voter), fixture, fixture.option_a)

    poll_vote =
      Repo.one!(
        from vote in PollVote,
          where: vote.user_id == ^voter.id and vote.poll_option_id == ^fixture.option_a.id
      )

    results =
      concurrently(
        for moderator <- moderators do
          fn ->
            PollVotes.delete_vote(
              actor(moderator),
              fixture.forum.short_name,
              fixture.topic.slug,
              poll_vote.id
            )
          end
        end
      )

    assert Enum.count(results, &match?({:ok, %Poll{}}, &1)) == 1
    assert Enum.count(results, &(&1 == {:error, :not_found})) == 1
    assert_consistent_poll(fixture, 0)
  end

  test "a ballot racing poll edits cannot change vote meaning after voting starts" do
    fixture = poll_fixture()
    moderator = actor(moderator_user_fixture())
    voter = confirmed_user_fixture()

    [vote_result, update_result] =
      concurrently([
        fn -> vote(actor(voter), fixture, fixture.option_a) end,
        fn ->
          Polls.update_poll(moderator, fixture.forum.short_name, fixture.topic.slug, %{
            "vote_method" => "multiple",
            "options" => %{
              "0" => %{"id" => fixture.option_a.id, "label" => "Changed A"},
              "1" => %{"id" => fixture.option_b.id, "label" => "Changed B"}
            }
          })
        end
      ])

    assert match?({:ok, _}, vote_result)

    case update_result do
      {:ok, _poll} ->
        # The edit acquired the poll lock first, so it was a valid pre-vote edit.
        assert Repo.reload!(fixture.option_a).label == "Changed A"
        assert Repo.reload!(fixture.poll).vote_method == "multiple"

      {:error, %Ecto.Changeset{} = changeset} ->
        assert "cannot be changed after voting has started" in errors_on(changeset).options
        assert "cannot be changed after voting has started" in errors_on(changeset).vote_method
        assert Repo.reload!(fixture.option_a).label == "Option A"
        assert Repo.reload!(fixture.poll).vote_method == "single"
    end

    assert_consistent_poll(fixture, 1)
  end

  test "concurrent edits after voting starts preserve the poll configuration" do
    fixture = poll_fixture()
    voter = confirmed_user_fixture()
    moderator = actor(moderator_user_fixture())
    {:ok, _} = vote(actor(voter), fixture, fixture.option_a)

    results =
      concurrently(
        for title <- ["First", "Second", "Third", "Fourth"] do
          fn ->
            Polls.update_poll(moderator, fixture.forum.short_name, fixture.topic.slug, %{
              "title" => title,
              "vote_method" => "multiple",
              "options" => %{
                "0" => %{"id" => fixture.option_a.id, "label" => title <> " A"},
                "1" => %{"id" => fixture.option_b.id, "label" => title <> " B"}
              }
            })
          end
        end
      )

    assert Enum.all?(results, &match?({:error, %Ecto.Changeset{}}, &1))
    assert Repo.reload!(fixture.poll).vote_method == "single"
    assert Repo.reload!(fixture.option_a).label == "Option A"
    assert Repo.reload!(fixture.option_b).label == "Option B"
    assert_consistent_poll(fixture, 1)
  end
end
