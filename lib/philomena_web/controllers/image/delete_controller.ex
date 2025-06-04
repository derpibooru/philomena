defmodule PhilomenaWeb.Image.DeleteController do
  use PhilomenaWeb, :controller

  # N.B.: this would be Image.Hide, because it hides the image, but that is
  # taken by the user action

  alias Philomena.Images.Image
  alias Philomena.Images

  plug PhilomenaWeb.CanaryMapPlug, create: :hide, update: :hide, delete: :hide
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true
  plug :verify_deleted when action in [:update]

  def create(conn, %{"image" => image_params}) do
    image = conn.assigns.image
    user = conn.assigns.current_user

    case Images.hide_image(image, user, image_params) do
      {:ok, result} ->
        conn
        |> put_flash(:info, "Image successfully deleted.")
        |> moderation_log(details: &log_details/2, data: result.image)
        |> redirect(to: ~p"/images/#{image}")

      _error ->
        conn
        |> put_flash(:error, "Failed to delete image.")
        |> redirect(to: ~p"/images/#{image}")
    end
  end

  def update(conn, %{"image" => image_params}) do
    image = conn.assigns.image

    case Images.update_hide_reason(image, image_params) do
      {:ok, image} ->
        conn
        |> put_flash(:info, "Deletion reason updated.")
        |> moderation_log(details: &log_details/2, data: image)
        |> redirect(to: ~p"/images/#{image}")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Couldn't update deletion reason.")
        |> redirect(to: ~p"/images/#{image}")
    end
  end

  defp verify_deleted(conn, _opts) do
    if conn.assigns.image.hidden_from_users do
      conn
    else
      conn
      |> put_flash(:error, "Cannot change deletion reason on a non-deleted image!")
      |> redirect(to: ~p"/images/#{conn.assigns.image}")
      |> halt()
    end
  end

  def delete(conn, _params) do
    image = conn.assigns.image

    {:ok, image} = Images.unhide_image(image)

    conn
    |> put_flash(:info, "Image successfully restored.")
    |> moderation_log(details: &log_details/2, data: image)
    |> redirect(to: ~p"/images/#{image}")
  end

  defp log_details(action, image) do
    body =
      case action do
        :create -> "Deleted image #{image.id} (#{image.deletion_reason})"
        :update -> "Changed deletion reason of #{image.id} (#{image.deletion_reason})"
        :delete -> "Restored image #{image.id}"
      end

    %{
      body: body,
      subject_path: ~p"/images/#{image}"
    }
  end
end
