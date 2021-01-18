defmodule Philomena.PollVotes do
  @moduledoc """
  The PollVotes context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo

  alias Philomena.Polls
  alias Philomena.Polls.Poll
  alias Philomena.PollVotes.PollVote
  alias Philomena.PollOptions.PollOption

  @doc """
  Gets a single poll_vote.

  Raises `Ecto.NoResultsError` if the Poll vote does not exist.

  ## Examples

      iex> get_poll_vote!(123)
      %PollVote{}

      iex> get_poll_vote!(456)
      ** (Ecto.NoResultsError)

  """
  def get_poll_vote!(id), do: Repo.get!(PollVote, id)

  @doc """
  Creates a poll_vote.

  ## Examples

      iex> create_poll_vote(%{field: value})
      {:ok, %PollVote{}}

      iex> create_poll_vote(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_poll_votes(user, poll, attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    poll_votes = filter_options(user, poll, now, attrs)

    Multi.new()
    |> Multi.run(:lock, fn repo, _ ->
      poll =
        Poll
        |> where(id: ^poll.id)
        |> lock("FOR UPDATE")
        |> repo.one()

      {:ok, poll}
    end)
    |> Multi.run(:ended, fn _repo, _changes ->
      # Bail if poll is no longer active
      case Polls.active?(poll) do
        false -> {:error, []}
        _true -> {:ok, []}
      end
    end)
    |> Multi.run(:existing_votes, fn _repo, _changes ->
      # Don't proceed if any votes exist
      case voted?(poll, user) do
        true -> {:error, []}
        _false -> {:ok, []}
      end
    end)
    |> Multi.run(:new_votes, fn repo, _changes ->
      {_count, votes} = repo.insert_all(PollVote, poll_votes, returning: true)

      {:ok, votes}
    end)
    |> Multi.run(:update_option_counts, fn repo, %{new_votes: new_votes} ->
      option_ids = Enum.map(new_votes, & &1.poll_option_id)

      {count, nil} =
        PollOption
        |> where([po], po.id in ^option_ids)
        |> repo.update_all(inc: [vote_count: 1])

      {:ok, count}
    end)
    |> Multi.run(:update_poll_votes_count, fn repo, %{new_votes: new_votes} ->
      length = length(new_votes)

      {count, nil} =
        Poll
        |> where(id: ^poll.id)
        |> repo.update_all(inc: [total_votes: length])

      {:ok, count}
    end)
    |> Repo.transaction()
  end

  defp filter_options(user, poll, now, %{"option_ids" => options}) when is_list(options) do
    # TODO: enforce integrity at the constraint level

    votes =
      options
      |> Enum.map(&String.to_integer/1)
      |> Enum.uniq()
      |> Enum.map(&%{poll_option_id: &1, user_id: user.id, created_at: now})

    case poll.vote_method do
      "single" -> Enum.take(votes, 1)
      _other -> votes
    end
  end

  defp filter_options(_user, _poll, _now, _attrs), do: []

  def voted?(nil, _user), do: false
  def voted?(_poll, nil), do: false

  def voted?(%{id: poll_id}, %{id: user_id}) do
    PollVote
    |> join(:inner, [pv], _ in assoc(pv, :poll_option))
    |> where([pv, po], po.poll_id == ^poll_id and pv.user_id == ^user_id)
    |> Repo.exists?()
  end

  @doc """
  Updates a poll_vote.

  ## Examples

      iex> update_poll_vote(poll_vote, %{field: new_value})
      {:ok, %PollVote{}}

      iex> update_poll_vote(poll_vote, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_poll_vote(%PollVote{} = poll_vote, attrs) do
    poll_vote
    |> PollVote.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a PollVote.

  ## Examples

      iex> delete_poll_vote(poll_vote)
      {:ok, %PollVote{}}

      iex> delete_poll_vote(poll_vote)
      {:error, %Ecto.Changeset{}}

  """
  def delete_poll_vote(%PollVote{} = poll_vote) do
    Repo.delete(poll_vote)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking poll_vote changes.

  ## Examples

      iex> change_poll_vote(poll_vote)
      %Ecto.Changeset{source: %PollVote{}}

  """
  def change_poll_vote(%PollVote{} = poll_vote) do
    PollVote.changeset(poll_vote, %{})
  end
end
