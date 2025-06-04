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
      {:ok, image} ->
        conn
        |> put_flash(:info, "Image contents destroyed.")
        |> moderation_log(details: &log_details/2, data: image)
        |> redirect(to: ~p"/images/#{image}")

      _error ->
        conn
        |> put_flash(:error, "Failed to destroy image.")
        |> redirect(to: ~p"/images/#{image}")
    end
  end

  defp verify_deleted(conn, _opts) do
    if conn.assigns.image.hidden_from_users do
      conn
    else
      conn
      |> put_flash(:error, "Cannot destroy a non-deleted image!")
      |> redirect(to: ~p"/images/#{conn.assigns.image}")
      |> halt()
    end
  end

  defp log_details(_action, image) do
    %{
      body: "Hard-deleted image #{image.id}",
      subject_path: ~p"/images/#{image}"
    }
  end
end
