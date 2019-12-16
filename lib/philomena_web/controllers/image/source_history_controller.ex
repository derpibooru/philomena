defmodule PhilomenaWeb.Image.SourceHistoryController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images

  plug PhilomenaWeb.CanaryMapPlug, delete: :hide
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  def delete(conn, _params) do
    {:ok, image} = Images.remove_source_history(conn.assigns.image)

    Images.reindex_image(image)

    conn
    |> put_flash(:info, "Successfully deleted source history.")
    |> redirect(to: Routes.image_path(conn, :show, image))
  end
end
