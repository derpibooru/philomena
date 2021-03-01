defmodule PhilomenaWeb.Image.TagLockController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images

  plug PhilomenaWeb.CanaryMapPlug, show: :hide, update: :hide, create: :hide, delete: :hide

  plug :load_and_authorize_resource,
    model: Image,
    id_name: "image_id",
    persisted: true,
    preload: [:locked_tags]

  def show(conn, _params) do
    changeset = Images.change_image(conn.assigns.image)

    render(conn, "show.html", title: "Locking image tags", changeset: changeset)
  end

  def update(conn, %{"image" => image_attrs}) do
    {:ok, image} = Images.update_locked_tags(conn.assigns.image, image_attrs)

    conn
    |> put_flash(:info, "Successfully updated list of locked tags.")
    |> redirect(to: Routes.image_path(conn, :show, image))
  end

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
