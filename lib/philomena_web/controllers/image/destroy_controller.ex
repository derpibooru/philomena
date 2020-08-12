defmodule PhilomenaWeb.Image.DestroyController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images

  plug PhilomenaWeb.CanaryMapPlug, create: :destroy
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true
  plug :verify_deleted when action in [:create]

  def create(conn, _params) do
    image = conn.assigns.image

    case Images.destroy_image(image) do
      {:ok, %{image: image}} ->
        conn
        |> put_flash(:info, "Image contents destroyed.")
        |> redirect(to: Routes.image_path(conn, :show, image))

      _error ->
        conn
        |> put_flash(:error, "Failed to destroy image.")
        |> redirect(to: Routes.image_path(conn, :show, image))
    end
  end

  defp verify_deleted(conn, _opts) do
    case conn.assigns.image.hidden_from_users do
      true ->
        conn

      _false ->
        conn
        |> put_flash(:error, "Cannot destroy a non-hidden image!")
        |> redirect(to: Routes.image_path(conn, :show, conn.assigns.image))
        |> halt()
    end
  end
end