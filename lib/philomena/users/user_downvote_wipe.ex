defmodule Philomena.Users.UserDownvoteWipe do
  @moduledoc """
  Performs the asynchronous vote/favorite cleanup owned by the Users context.

  The public entry point accepts only a trusted persisted user ID and is called
  by `Philomena.UserUnvoteWorker` after an authorized Users service enqueues it.
  """

  import Ecto.Query

  alias PhilomenaQuery.Search
  alias Philomena.Users
  alias Philomena.Images.Image
  alias Philomena.Images
  alias Philomena.ImageVotes
  alias Philomena.ImageFaves
  alias Philomena.Repo

  defp reindex(image_ids) do
    Image
    |> where([i], i.id in ^image_ids)
    |> preload(^Images.indexing_preloads())
    |> Search.reindex(Image)

    # Allow time for indexing to catch up before the next destructive batch.
    :timer.sleep(:timer.seconds(10))
  end

  @doc """
  Removes a user's downvotes and, when requested, their upvotes and favorites.

  A missing ID is an invariant violation and raises. Affected image and user
  counters are updated in batches, and affected images are reindexed after each
  batch.

  ## Examples

      iex> UserDownvoteWipe.perform(user.id)
      :ok

      iex> UserDownvoteWipe.perform(user.id, true)
      :ok
  """
  @spec perform(integer(), boolean()) :: :ok
  def perform(user_id, upvotes_and_faves_too \\ false) do
    user = Users.fetch_user_for_worker!(user_id)

    {count, image_ids} = ImageVotes.delete_user_votes!(user.id, false)
    Images.decrement_vote_counters!(image_ids, false)
    Users.increment_counter(Repo, user.id, :image_votes_count, -count)
    reindex(image_ids)

    if upvotes_and_faves_too do
      {count, image_ids} = ImageVotes.delete_user_votes!(user.id, true)
      Images.decrement_vote_counters!(image_ids, true)
      Users.increment_counter(Repo, user.id, :image_votes_count, -count)
      reindex(image_ids)

      {count, image_ids} = ImageFaves.delete_user_faves!(user.id)
      Images.decrement_fave_counters!(image_ids)
      Users.increment_counter(Repo, user.id, :image_faves_count, -count)
      reindex(image_ids)
    end

    :ok
  end
end
