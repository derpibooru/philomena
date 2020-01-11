defmodule Philomena.ImageHides do
  @moduledoc """
  The ImageHides context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi

  alias Philomena.Images.Image
  alias Philomena.ImageHides.ImageHide

  @doc """
  Creates a image_hide.

  """
  def create_hide_transaction(image, user) do
    hide =
      %ImageHide{image_id: image.id, user_id: user.id}
      |> ImageHide.changeset(%{})

    image_query =
      Image
      |> where(id: ^image.id)

    Multi.new()
    |> Multi.insert(:hide, hide)
    |> Multi.update_all(:inc_hides_count, image_query, inc: [hides_count: 1])
  end

  @doc """
  Deletes a ImageHide.

  """
  def delete_hide_transaction(image, user) do
    hide_query =
      ImageHide
      |> where(image_id: ^image.id)
      |> where(user_id: ^user.id)

    image_query =
      Image
      |> where(id: ^image.id)

    Multi.new()
    |> Multi.delete_all(:unhide, hide_query)
    |> Multi.run(:dec_hides_count, fn repo, %{unhide: {hides, nil}} ->
      {count, nil} =
        image_query
        |> repo.update_all(inc: [hides_count: -hides])

      {:ok, count}
    end)
  end
end
