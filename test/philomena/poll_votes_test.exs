defmodule Philomena.PollVotesTest do
  use Philomena.DataCase

  alias Philomena.PollVotes

  describe "poll_votes" do
    alias Philomena.PollVotes.PollVote

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def poll_vote_fixture(attrs \\ %{}) do
      {:ok, poll_vote} =
        attrs
        |> Enum.into(@valid_attrs)
        |> PollVotes.create_poll_vote()

      poll_vote
    end

    test "list_poll_votes/0 returns all poll_votes" do
      poll_vote = poll_vote_fixture()
      assert PollVotes.list_poll_votes() == [poll_vote]
    end

    test "get_poll_vote!/1 returns the poll_vote with given id" do
      poll_vote = poll_vote_fixture()
      assert PollVotes.get_poll_vote!(poll_vote.id) == poll_vote
    end

    test "create_poll_vote/1 with valid data creates a poll_vote" do
      assert {:ok, %PollVote{} = poll_vote} = PollVotes.create_poll_vote(@valid_attrs)
    end

    test "create_poll_vote/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = PollVotes.create_poll_vote(@invalid_attrs)
    end

    test "update_poll_vote/2 with valid data updates the poll_vote" do
      poll_vote = poll_vote_fixture()
      assert {:ok, %PollVote{} = poll_vote} = PollVotes.update_poll_vote(poll_vote, @update_attrs)
    end

    test "update_poll_vote/2 with invalid data returns error changeset" do
      poll_vote = poll_vote_fixture()
      assert {:error, %Ecto.Changeset{}} = PollVotes.update_poll_vote(poll_vote, @invalid_attrs)
      assert poll_vote == PollVotes.get_poll_vote!(poll_vote.id)
    end

    test "delete_poll_vote/1 deletes the poll_vote" do
      poll_vote = poll_vote_fixture()
      assert {:ok, %PollVote{}} = PollVotes.delete_poll_vote(poll_vote)
      assert_raise Ecto.NoResultsError, fn -> PollVotes.get_poll_vote!(poll_vote.id) end
    end

    test "change_poll_vote/1 returns a poll_vote changeset" do
      poll_vote = poll_vote_fixture()
      assert %Ecto.Changeset{} = PollVotes.change_poll_vote(poll_vote)
    end
  end
end
