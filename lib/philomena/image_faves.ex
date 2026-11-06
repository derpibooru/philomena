defmodule Philomena.ImageFaves do
  @moduledoc """
  Transaction steps for favorite rows owned by `Philomena.Images`.

  This module performs no authorization. Its functions require an
  already-loaded image and user after the owning context has enforced
  prerequisites.
  """

  import Ecto.Query, warn: false

  alias Philomena.Multi
  alias Philomena.ImageFaves.ImageFave
  alias Philomena.Images
  alias Philomena.Images.Image
  alias Philomena.UserStatistics
  alias Philomena.Users.User
  alias Philomena.Repo
  alias PhilomenaQuery.Batch

  defp delete_fave_steps(multi, image, user) do
    fave_query =
      ImageFave
      |> where(image_id: ^image.id)
      |> where(user_id: ^user.id)

    multi
    |> Multi.delete_all(:unfave, fave_query)
    |> Images.put_image_counter_delta(:dec_faves_count, image.id, :faves_count, fn
      %{unfave: {faves, nil}} -> -faves
    end)
    |> Multi.merge(fn %{unfave: {faves, nil}} ->
      UserStatistics.put_increment(Multi.new(), user, :image_faves_count, -faves)
    end)
  end

  @doc """
  Adds favorite steps for a loaded image and user to `multi`.

  The caller must have authorized the loaded image. The steps first remove any
  existing favorite, adjusting `faves_count` and the user's image-fave
  statistic by the number of rows removed, and then insert one row and add one
  to both counters. Repeated execution is therefore idempotent. The changes are
  named `:unfave`, `:dec_faves_count`, `:fave`, `:inc_faves_count`, and
  `:inc_fave_stat`.

  ## Examples

      iex> (Multi.new()
      ...> |> put_fave_for_loaded_image(image, user)
      ...> |> Multi.transact())
      {:ok, %{fave: %ImageFave{}}}

  """
  @spec put_fave_for_loaded_image(Multi.t(), Image.t(), User.t()) :: Multi.t()
  def put_fave_for_loaded_image(%Multi{} = multi, %Image{} = image, %User{} = user) do
    fave =
      %ImageFave{image_id: image.id, user_id: user.id}
      |> ImageFave.changeset(%{})

    multi
    |> delete_fave_steps(image, user)
    |> Multi.insert(:fave, fave)
    |> Images.put_image_counter_delta(:inc_faves_count, image.id, :faves_count, 1)
    |> UserStatistics.put_increment(user, :image_faves_count, 1)
  end

  @doc """
  Adds favorite deletion steps for a loaded image and user to `multi`.

  The caller must have authorized the loaded image.`:dec_faves_count` adjusts
  the image and user counters by that exact number, so deleting an absent
  favorite changes nothing.

  ## Examples

      iex> (Multi.new()
      ...> |> delete_fave_for_loaded_image(image, user)
      ...> |> Multi.transact())
      {:ok, %{unfave: {0, nil}}}

  """
  @spec delete_fave_for_loaded_image(Multi.t(), Image.t(), User.t()) :: Multi.t()
  def delete_fave_for_loaded_image(%Multi{} = multi, %Image{} = image, %User{} = user) do
    delete_fave_steps(multi, image, user)
  end

  @doc """
  Deletes all of a user's favorites in batches and returns `{count, image_ids}`.

  Image and user counters are adjusted by their owning contexts afterward.
  """
  @spec delete_user_faves!(integer()) :: {non_neg_integer(), [integer()]}
  def delete_user_faves!(user_id) when is_integer(user_id) do
    ImageFave
    |> where(user_id: ^user_id)
    |> Batch.query_batches(id_field: :image_id)
    |> Enum.reduce({0, []}, fn batch, {count, image_ids} ->
      ids = Repo.all(select(batch, [fave], fave.image_id))
      {deleted, _} = Repo.delete_all(batch)
      {count + deleted, ids ++ image_ids}
    end)
    |> then(fn {count, image_ids} -> {count, Enum.uniq(image_ids)} end)
  end

  @doc """
  Inserts image favorite interactions for a merge target inside `multi`.

  The source interaction snapshot is expected at `:interaction_source`.
  """
  @spec put_migrate_image_interactions(Multi.t(), Image.t()) :: Multi.t()
  def put_migrate_image_interactions(%Multi{} = multi, %Image{} = target) do
    multi
    |> Multi.run(
      :interaction_faves,
      fn repo, %{interaction_source: %{source: source, created_at: created_at}} ->
        rows =
          Enum.map(source.favers, &%{image_id: target.id, user_id: &1.id, created_at: created_at})

        {count, inserted} =
          repo.insert_all(ImageFave, rows,
            on_conflict: :nothing,
            returning: [:user_id]
          )

        {:ok, {count, inserted}}
      end
    )
    |> Multi.merge(fn %{interaction_faves: {_count, rows}} ->
      UserStatistics.put_bulk_increment(
        Multi.new(),
        Enum.map(rows, & &1.user_id),
        :image_faves_count
      )
    end)
  end
end
