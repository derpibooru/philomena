defmodule PhilomenaWeb.Image.SourceHistoryController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images

  plug PhilomenaWeb.CanaryMapPlug, delete: :hide
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  def delete(conn, _params) do
    {:ok, image} = Images.remove_source_history(conn.assigns.image)

    Images.reindex_image(image)

    conn
    |> put_flash(:info, "Successfully deleted source history.")
    |> moderation_log(details: &log_details/3, data: image)
    |> redirect(to: ~p"/images/#{image}")
  end

  defp log_details(_conn, _action, image) do
    %{
      body: "Deleted source history for image >>#{image.id}",
      subject_path: ~p"/images/#{image}"
    }
  end
end
