defmodule Philomena.ImageVotes do
  @moduledoc """
  Transaction steps for vote rows owned by `Philomena.Images`.

  This module performs no authorization. Its functions require an
  already-loaded image and user after the owning context has enforced
  prerequisites.
  """

  import Ecto.Query, warn: false

  alias Philomena.Multi
  alias Philomena.Images
  alias Philomena.Images.Image
  alias Philomena.ImageVotes.ImageVote
  alias Philomena.UserStatistics
  alias Philomena.Users.User
  alias Philomena.Repo
  alias PhilomenaQuery.Batch

  defp delete_vote_steps(multi, image, user) do
    user_vote_query =
      ImageVote
      |> where(image_id: ^image.id)
      |> where(user_id: ^user.id)

    multi
    |> Multi.delete_all(:unupvote, where(user_vote_query, up: true))
    |> Multi.delete_all(:undownvote, where(user_vote_query, up: false))
    |> Images.put_image_counter_delta(:dec_upvotes_count, image.id, :upvotes_count, fn
      %{unupvote: {upvotes, nil}} -> -upvotes
    end)
    |> Images.put_image_counter_delta(:dec_downvotes_count, image.id, :downvotes_count, fn
      %{undownvote: {downvotes, nil}} -> -downvotes
    end)
    |> Images.put_image_counter_delta(:dec_score, image.id, :score, fn
      %{unupvote: {upvotes, nil}, undownvote: {downvotes, nil}} -> downvotes - upvotes
    end)
    |> Multi.merge(fn %{unupvote: {upvotes, nil}, undownvote: {downvotes, nil}} ->
      UserStatistics.put_increment(Multi.new(), user, :image_votes_count, -(upvotes + downvotes))
    end)
  end

  @doc """
  Adds vote steps for a loaded image and user to `multi`.

  The caller must have authorized the image. Any existing direction is removed
  before the requested direction is inserted, with score, image direction counters,
  and the user's vote statistic adjusted by the actual row deltas. Repeated votes
  and direction changes are idempotent. The changes are named `:unupvote`,
  `:undownvote`, `:dec_votes_count`, `:vote`, `:inc_vote_count`, and `:inc_vote_stat`.

  ## Examples

      iex> (Multi.new()
      ...> |> put_vote_for_loaded_image(image, user, true)
      ...> |> Multi.transact())
      {:ok, %{vote: %ImageVote{up: true}}}

  """
  @spec put_vote_for_loaded_image(Multi.t(), Image.t(), User.t(), boolean()) :: Multi.t()
  def put_vote_for_loaded_image(%Multi{} = multi, %Image{} = image, %User{} = user, up)
      when is_boolean(up) do
    vote =
      %ImageVote{image_id: image.id, user_id: user.id, up: up}
      |> ImageVote.changeset(%{})

    upvotes = if up, do: 1, else: 0
    downvotes = if up, do: 0, else: 1

    multi
    |> delete_vote_steps(image, user)
    |> Multi.insert(:vote, vote)
    |> Images.put_image_counter_delta(:inc_upvotes_count, image.id, :upvotes_count, upvotes)
    |> Images.put_image_counter_delta(:inc_downvotes_count, image.id, :downvotes_count, downvotes)
    |> Images.put_image_counter_delta(:inc_score, image.id, :score, upvotes - downvotes)
    |> UserStatistics.put_increment(user, :image_votes_count, 1)
  end

  @doc """
  Adds vote deletion steps for a loaded image and user to `multi`.

  The caller must have authorized the loaded image. The two delete changes
  report the removed direction, and `:dec_votes_count` adjusts score, image
  counters, and the user statistic by those exact deltas. Deleting an absent
  vote changes nothing.

  ## Examples

      iex> (Multi.new()
      ...> |> delete_vote_for_loaded_image(image, user)
      ...> |> Multi.transact())
      {:ok, %{unupvote: {0, nil}, undownvote: {0, nil}}}

  """
  @spec delete_vote_for_loaded_image(Multi.t(), Image.t(), User.t()) :: Multi.t()
  def delete_vote_for_loaded_image(%Multi{} = multi, %Image{} = image, %User{} = user) do
    delete_vote_steps(multi, image, user)
  end

  @doc """
  Deletes all of a user's votes in batches and returns `{count, image_ids}`.

  Image counters and the user's lifetime counter are adjusted separately by
  their owning contexts.
  """
  @spec delete_user_votes!(integer(), boolean()) :: {non_neg_integer(), [integer()]}
  def delete_user_votes!(user_id, up) when is_integer(user_id) and is_boolean(up) do
    query = where(ImageVote, user_id: ^user_id, up: ^up)

    query
    |> Batch.query_batches(id_field: :image_id)
    |> Enum.reduce({0, []}, fn batch, {count, image_ids} ->
      ids = Repo.all(select(batch, [vote], vote.image_id))
      {deleted, _} = Repo.delete_all(batch)
      {count + deleted, ids ++ image_ids}
    end)
    |> then(fn {count, image_ids} -> {count, Enum.uniq(image_ids)} end)
  end

  @doc """
  Inserts image vote interactions for a merge target inside `multi`.

  The source interaction snapshot is expected at `:interaction_source`.
  """
  @spec put_migrate_image_interactions(Multi.t(), Image.t(), Multi.name(), boolean()) :: Multi.t()
  def put_migrate_image_interactions(%Multi{} = multi, %Image{} = target, step, up)
      when is_boolean(up) do
    multi
    |> Multi.run(step, fn repo,
                          %{interaction_source: %{source: source, created_at: created_at}} ->
      voters = if up, do: source.upvoters, else: source.downvoters

      rows =
        Enum.map(voters, &%{image_id: target.id, user_id: &1.id, created_at: created_at, up: up})

      {count, inserted} =
        repo.insert_all(ImageVote, rows,
          on_conflict: :nothing,
          returning: [:user_id]
        )

      {:ok, {count, inserted}}
    end)
    |> Multi.merge(fn %{^step => {_count, rows}} ->
      UserStatistics.put_bulk_increment(
        Multi.new(),
        Enum.map(rows, & &1.user_id),
        :image_votes_count
      )
    end)
  end
end
