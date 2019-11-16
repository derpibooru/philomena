defmodule Philomena.ImageVotes do
  @moduledoc """
  The ImageVotes context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.ImageVotes.ImageVote

  @doc """
  Returns the list of image_votes.

  ## Examples

      iex> list_image_votes()
      [%ImageVote{}, ...]

  """
  def list_image_votes do
    Repo.all(ImageVote)
  end

  @doc """
  Gets a single image_vote.

  Raises `Ecto.NoResultsError` if the Image vote does not exist.

  ## Examples

      iex> get_image_vote!(123)
      %ImageVote{}

      iex> get_image_vote!(456)
      ** (Ecto.NoResultsError)

  """
  def get_image_vote!(id), do: Repo.get!(ImageVote, id)

  @doc """
  Creates a image_vote.

  ## Examples

      iex> create_image_vote(%{field: value})
      {:ok, %ImageVote{}}

      iex> create_image_vote(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_image_vote(attrs \\ %{}) do
    %ImageVote{}
    |> ImageVote.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a image_vote.

  ## Examples

      iex> update_image_vote(image_vote, %{field: new_value})
      {:ok, %ImageVote{}}

      iex> update_image_vote(image_vote, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_image_vote(%ImageVote{} = image_vote, attrs) do
    image_vote
    |> ImageVote.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ImageVote.

  ## Examples

      iex> delete_image_vote(image_vote)
      {:ok, %ImageVote{}}

      iex> delete_image_vote(image_vote)
      {:error, %Ecto.Changeset{}}

  """
  def delete_image_vote(%ImageVote{} = image_vote) do
    Repo.delete(image_vote)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking image_vote changes.

  ## Examples

      iex> change_image_vote(image_vote)
      %Ecto.Changeset{source: %ImageVote{}}

  """
  def change_image_vote(%ImageVote{} = image_vote) do
    ImageVote.changeset(image_vote, %{})
  end
end
