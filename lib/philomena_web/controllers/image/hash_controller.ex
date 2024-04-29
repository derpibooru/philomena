defmodule PhilomenaWeb.Image.HashController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images

  plug PhilomenaWeb.CanaryMapPlug, delete: :hide
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  def delete(conn, _params) do
    {:ok, image} = Images.remove_hash(conn.assigns.image)

    conn
    |> put_flash(:info, "Successfully cleared hash.")
    |> moderation_log(details: &log_details/3, data: image)
    |> redirect(to: ~p"/images/#{image}")
  end

  defp log_details(conn, _action, image) do
    %{
      body: "Cleared hash of image >>#{image.id}",
      subject_path: ~p"/images/#{image}"
    }
  end
end
