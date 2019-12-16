defmodule PhilomenaWeb.Image.RepairController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images

  plug PhilomenaWeb.CanaryMapPlug, create: :hide
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true
  plug :verify_not_deleted

  def create(conn, _params) do
    spawn fn ->
      Images.repair_image(conn.assigns.image)
    end

    conn
    |> put_flash(:info, "Repair job started.")
    |> redirect(to: Routes.image_path(conn, :show, conn.assigns.image))
  end

  defp verify_not_deleted(conn, _opts) do
    case conn.assigns.image.hidden_from_users do
      true ->
        conn
        |> put_flash(:error, "Cannot repair a hidden image.")
        |> redirect(to: Routes.image_path(conn, :show, conn.assigns.image))

      _false ->
        conn
    end
  end
end
