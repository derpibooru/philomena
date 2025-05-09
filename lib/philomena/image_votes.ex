defmodule Philomena.ImageVotes do
  @moduledoc """
  The ImageVotes context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi

  alias Philomena.ImageVotes.ImageVote
  alias Philomena.UserStatistics
  alias Philomena.Images.Image

  @doc """
  Creates a image_vote.

  """
  def create_vote_transaction(image, user, up) do
    vote =
      %ImageVote{image_id: image.id, user_id: user.id, up: up}
      |> ImageVote.changeset(%{})

    image_query =
      Image
      |> where(id: ^image.id)

    upvotes = if up, do: 1, else: 0
    downvotes = if up, do: 0, else: 1

    Multi.new()
    |> Multi.insert(:vote, vote)
    |> Multi.update_all(:inc_vote_count, image_query,
      inc: [upvotes_count: upvotes, downvotes_count: downvotes, score: upvotes - downvotes]
    )
    |> Multi.run(:inc_vote_stat, fn _repo, _changes ->
      UserStatistics.inc_stat(user, :votes_cast, 1)
    end)
  end

  @doc """
  Deletes a ImageVote.

  """
  def delete_vote_transaction(image, user) do
    upvote_query =
      ImageVote
      |> where(image_id: ^image.id)
      |> where(user_id: ^user.id)
      |> where(up: true)

    downvote_query =
      ImageVote
      |> where(image_id: ^image.id)
      |> where(user_id: ^user.id)
      |> where(up: false)

    image_query =
      Image
      |> where(id: ^image.id)

    Multi.new()
    |> Multi.delete_all(:unupvote, upvote_query)
    |> Multi.delete_all(:undownvote, downvote_query)
    |> Multi.run(:dec_votes_count, fn repo,
                                      %{unupvote: {upvotes, nil}, undownvote: {downvotes, nil}} ->
      {count, nil} =
        image_query
        |> repo.update_all(
          inc: [upvotes_count: -upvotes, downvotes_count: -downvotes, score: downvotes - upvotes]
        )

      UserStatistics.inc_stat(user, :votes_cast, -(upvotes + downvotes))

      {:ok, count}
    end)
  end
end
