defmodule PhilomenaWeb.Gallery.OrderController do
  use PhilomenaWeb, :controller

  alias Philomena.Galleries.Gallery
  alias Philomena.Galleries

  plug PhilomenaWeb.CanaryMapPlug, update: :edit
  plug :load_and_authorize_resource, model: Gallery, id_name: "gallery_id", persisted: true

  def update(conn, %{"image_ids" => image_ids}) when is_list(image_ids) do
    gallery = conn.assigns.gallery

    Galleries.reorder_gallery(gallery, image_ids)

    json(conn, %{})
  end
end
