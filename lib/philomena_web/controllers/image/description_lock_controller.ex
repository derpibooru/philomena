defmodule PhilomenaWeb.Image.DescriptionLockController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images

  plug PhilomenaWeb.CanaryMapPlug, create: :hide, delete: :hide
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  def create(conn, _params) do
    {:ok, image} = Images.lock_description(conn.assigns.image, true)

    conn
    |> put_flash(:info, "Successfully locked description.")
    |> redirect(to: Routes.image_path(conn, :show, image))
  end

  def delete(conn, _params) do
    {:ok, image} = Images.lock_description(conn.assigns.image, false)

    conn
    |> put_flash(:info, "Successfully unlocked description.")
    |> redirect(to: Routes.image_path(conn, :show, image))
  end
end
