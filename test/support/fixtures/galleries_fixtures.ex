defmodule Philomena.GalleriesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Galleries` context.
  """

  alias Philomena.Galleries
  alias Philomena.Repo
  alias Philomena.Users.User

  def unique_gallery_title, do: "Test Gallery #{System.unique_integer([:positive])}"

  @doc """
  Creates a gallery owned by `user`.

  A gallery requires a thumbnail image; when `:thumbnail_id` is not given,
  a fresh `Philomena.ImagesFixtures.image_fixture/1` is created for it.
  """
  def gallery_fixture(user, attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{title: unique_gallery_title()})
      |> Map.put_new_lazy(:thumbnail_id, fn -> Philomena.ImagesFixtures.image_fixture().id end)

    {:ok, gallery} = Galleries.create_gallery(Philomena.AttributionFixtures.actor(user), attrs)

    gallery
  end

  @doc """
  Adds `image` to `gallery` through the owner-authorized context boundary.
  """
  def gallery_image_fixture(gallery, image) do
    user = Repo.get!(User, gallery.user_id)

    {:ok, result} =
      Galleries.create_gallery_image(
        Philomena.AttributionFixtures.actor(user),
        gallery.id,
        image.id
      )

    result
  end
end
