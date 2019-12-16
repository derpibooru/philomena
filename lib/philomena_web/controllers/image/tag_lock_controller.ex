defmodule PhilomenaWeb.Image.TagLockController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images

  plug PhilomenaWeb.CanaryMapPlug, create: :hide, delete: :hide
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  def create(conn, _params) do
    {:ok, image} = Images.lock_tags(conn.assigns.image, true)

    conn
    |> put_flash(:info, "Successfully locked tags.")
    |> redirect(to: Routes.image_path(conn, :show, image))
  end

  def delete(conn, _params) do
    {:ok, image} = Images.lock_tags(conn.assigns.image, false)

    conn
    |> put_flash(:info, "Successfully unlocked tags.")
    |> redirect(to: Routes.image_path(conn, :show, image))
  end
end
