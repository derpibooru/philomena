defmodule PhilomenaWeb.Image.FileController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images

  plug PhilomenaWeb.CanaryMapPlug, update: :hide
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true
  plug :verify_not_deleted
  plug PhilomenaWeb.ScraperPlug, params_name: "image", params_key: "image"

  def update(conn, %{"image" => image_params}) do
    case Images.update_file(conn.assigns.image, image_params) do
      {:ok, image} ->
        conn
        |> put_flash(:info, "Successfully updated file.")
        |> redirect(to: Routes.image_path(conn, :show, image))

      _error ->
        conn
        |> put_flash(:error, "Failed to update file!")
        |> redirect(to: Routes.image_path(conn, :show, conn.assigns.image))
    end
  end

  defp verify_not_deleted(conn, _opts) do
    case conn.assigns.image.hidden_from_users do
      true ->
        conn
        |> put_flash(:error, "Cannot replace a hidden image.")
        |> redirect(to: Routes.image_path(conn, :show, conn.assigns.image))
        |> halt()

      _false ->
        conn
    end
  end
end
