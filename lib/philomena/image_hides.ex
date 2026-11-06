defmodule Philomena.ImageHides do
  @moduledoc """
  Transaction steps for hide rows owned by `Philomena.Images`.

  This module performs no authorization. Its functions require an
  already-loaded image and user after the owning context has enforced
  prerequisites.
  """

  import Ecto.Query, warn: false

  alias Philomena.Multi
  alias Philomena.ImageHides.ImageHide
  alias Philomena.Images
  alias Philomena.Images.Image
  alias Philomena.Users.User

  defp delete_hide_steps(multi, image, user) do
    hide_query =
      ImageHide
      |> where(image_id: ^image.id)
      |> where(user_id: ^user.id)

    multi
    |> Multi.delete_all(:unhide, hide_query)
    |> Images.put_image_counter_delta(:dec_hides_count, image.id, :hides_count, fn
      %{unhide: {hides, nil}} -> -hides
    end)
  end

  @doc """
  Adds hide steps for a loaded image and user to `multi`.

  The caller must have authorized the loaded image. The steps first remove any
  existing favorite, adjusting `hides_count` by the number of rows removed, and
  then insert one row and add one to both counters. Repeated execution is
  therefore idempotent. The changes are named `:unhide`, `:dec_hides_count`,
  `:hide`, and `:inc_hides_count`

  ## Examples

      iex> (Multi.new()
      ...> |> put_hide_for_loaded_image(image, user)
      ...> |> Multi.transact())
      {:ok, %{hide: %ImageHide{}}}

  """
  @spec put_hide_for_loaded_image(Multi.t(), Image.t(), User.t()) :: Multi.t()
  def put_hide_for_loaded_image(%Multi{} = multi, %Image{} = image, %User{} = user) do
    hide =
      %ImageHide{image_id: image.id, user_id: user.id}
      |> ImageHide.changeset(%{})

    multi
    |> delete_hide_steps(image, user)
    |> Multi.insert(:hide, hide)
    |> Images.put_image_counter_delta(:inc_hides_count, image.id, :hides_count, 1)
  end

  @doc """
  Adds hide deletion steps for a loaded image and user to `multi`.

  The caller must have authorized the loaded image. `:dec_hides_count` adjusts
  the image counter by that exact number, so deleting an absent hide changes
  nothing.

  ## Examples

      iex> (Multi.new()
      ...> |> delete_hide_for_loaded_image(image, user)
      ...> |> Multi.transact())
      {:ok, %{unhide: {0, nil}}}

  """
  @spec delete_hide_for_loaded_image(Multi.t(), Image.t(), User.t()) :: Multi.t()
  def delete_hide_for_loaded_image(%Multi{} = multi, %Image{} = image, %User{} = user) do
    delete_hide_steps(multi, image, user)
  end

  @doc """
  Inserts image hide interactions for a merge target inside `multi`.

  The source interaction snapshot is expected at `:interaction_source`.
  """
  @spec put_migrate_image_interactions(Multi.t(), Image.t()) :: Multi.t()
  def put_migrate_image_interactions(%Multi{} = multi, %Image{} = target) do
    Multi.run(
      multi,
      :interaction_hides,
      fn repo, %{interaction_source: %{source: source, created_at: created_at}} ->
        rows =
          Enum.map(source.hiders, &%{image_id: target.id, user_id: &1.id, created_at: created_at})

        {count, nil} = repo.insert_all(ImageHide, rows, on_conflict: :nothing)

        {:ok, count}
      end
    )
  end
end
