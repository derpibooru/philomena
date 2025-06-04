defmodule PhilomenaWeb.Image.FileController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images

  plug PhilomenaWeb.CanaryMapPlug, update: :hide
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true
  plug :verify_not_deleted
  plug PhilomenaWeb.ScraperPlug, params_name: "image", params_key: "image"

  def update(conn, %{"image" => image_params}) do
    Images.remove_hash(conn.assigns.image)

    case Images.update_file(conn.assigns.image, image_params) do
      {:ok, image} ->
        conn
        |> put_flash(:info, "Successfully updated file.")
        |> moderation_log(details: &log_details/2, data: image)
        |> redirect(to: ~p"/images/#{image}")

      _error ->
        conn
        |> put_flash(:error, "Failed to update file!")
        |> redirect(to: ~p"/images/#{conn.assigns.image}")
    end
  end

  defp verify_not_deleted(conn, _opts) do
    if conn.assigns.image.hidden_from_users do
      conn
      |> put_flash(:error, "Cannot replace a deleted image.")
      |> redirect(to: ~p"/images/#{conn.assigns.image}")
      |> halt()
    else
      conn
    end
  end

  defp log_details(_action, image) do
    %{body: "Updated file of image #{image.id}", subject_path: ~p"/images/#{image}"}
  end
end
