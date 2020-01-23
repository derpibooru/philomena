defmodule PhilomenaWeb.Gallery.ImageController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Galleries.Gallery
  alias Philomena.Images
  alias Philomena.Galleries

  plug PhilomenaWeb.FilterBannedUsersPlug

  plug PhilomenaWeb.CanaryMapPlug, create: :edit, delete: :edit
  plug :load_and_authorize_resource, model: Gallery, id_name: "gallery_id", persisted: true

  plug PhilomenaWeb.CanaryMapPlug, create: :show, delete: :show
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  def create(conn, _params) do
    gallery = conn.assigns.gallery
    image = conn.assigns.image

    {:ok, _gallery} = Galleries.add_image_to_gallery(gallery, image)
    Galleries.notify_gallery(gallery)
    Galleries.reindex_gallery(gallery)
    Images.reindex_image(image)

    json(conn, %{})
  end

  def delete(conn, _params) do
    gallery = conn.assigns.gallery
    image = conn.assigns.image

    {:ok, _gallery} = Galleries.remove_image_from_gallery(gallery, image)
    Galleries.reindex_gallery(gallery)
    Images.reindex_image(image)

    json(conn, %{})
  end
end
