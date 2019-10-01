defmodule Philomena.PollVotes do
  @moduledoc """
  The PollVotes context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.PollVotes.PollVote

  @doc """
  Returns the list of poll_votes.

  ## Examples

      iex> list_poll_votes()
      [%PollVote{}, ...]

  """
  def list_poll_votes do
    Repo.all(PollVote)
  end

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
  def create_poll_vote(attrs \\ %{}) do
    %PollVote{}
    |> PollVote.changeset(attrs)
    |> Repo.insert()
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
