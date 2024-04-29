defmodule PhilomenaWeb.Image.CommentLockController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images

  plug PhilomenaWeb.CanaryMapPlug, create: :hide, delete: :hide
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  def create(conn, _params) do
    {:ok, image} = Images.lock_comments(conn.assigns.image, true)

    conn
    |> put_flash(:info, "Successfully locked comments.")
    |> moderation_log(details: &log_details/3, data: image)
    |> redirect(to: ~p"/images/#{image}")
  end

  def delete(conn, _params) do
    {:ok, image} = Images.lock_comments(conn.assigns.image, false)

    conn
    |> put_flash(:info, "Successfully unlocked comments.")
    |> moderation_log(details: &log_details/3, data: image)
    |> redirect(to: ~p"/images/#{image}")
  end

  defp log_details(_conn, action, image) do
    body =
      case action do
        :create -> "Locked comments on image >>#{image.id}"
        :delete -> "Unlocked comments on image >>#{image.id}"
      end

    %{
      body: body,
      subject_path: ~p"/images/#{image}"
    }
  end
end
