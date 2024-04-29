defmodule PhilomenaWeb.Image.RepairController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images

  plug PhilomenaWeb.CanaryMapPlug, create: :hide
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  def create(conn, _params) do
    Images.repair_image(conn.assigns.image)
    Images.purge_files(conn.assigns.image, conn.assigns.image.hidden_image_key)

    conn
    |> put_flash(:info, "Repair job enqueued.")
    |> moderation_log(details: &log_details/3, data: conn.assigns.image)
    |> redirect(to: ~p"/images/#{conn.assigns.image}")
  end

  defp log_details(_conn, _action, image) do
    %{
      body: "Repaired image >>#{image.id}",
      subject_path: ~p"/images/#{image}"
    }
  end
end
