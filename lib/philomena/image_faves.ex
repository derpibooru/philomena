defmodule Philomena.ImageFaves do
  @moduledoc """
  The ImageFaves context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi

  alias Philomena.ImageFaves.ImageFave
  alias Philomena.UserStatistics
  alias Philomena.Images.Image

  @doc """
  Creates a image_hide.

  """
  def create_fave_transaction(image, user) do
    fave =
      %ImageFave{image_id: image.id, user_id: user.id}
      |> ImageFave.changeset(%{})

    image_query =
      Image
      |> where(id: ^image.id)

    Multi.new
    |> Multi.insert(:fave, fave)
    |> Multi.update_all(:inc_faves_count, image_query, inc: [faves_count: 1])
    |> Multi.run(:inc_fave_stat, fn _repo, _changes ->
      UserStatistics.inc_stat(user, :images_favourited, 1)
    end)
  end

  @doc """
  Deletes a ImageFave.

  """
  def delete_fave_transaction(image, user) do
    fave_query =
      ImageFave
      |> where(image_id: ^image.id)
      |> where(user_id: ^user.id)

    image_query =
      Image
      |> where(id: ^image.id)

    Multi.new
    |> Multi.delete_all(:unfave, fave_query)
    |> Multi.run(:dec_faves_count, fn repo, %{unfave: {faves, nil}} ->
      {count, nil} =
        image_query
        |> repo.update_all(inc: [faves_count: -faves])

      UserStatistics.inc_stat(user, :images_favourited, -faves)

      {:ok, count}
    end)
  end
end
