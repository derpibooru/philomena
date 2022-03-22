defmodule PhilomenaWeb.Image.ApproveController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images

  plug PhilomenaWeb.CanaryMapPlug, create: :approve
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  def create(conn, _params) do
    image = conn.assigns.image

    {:ok, _comment} = Images.approve_image(image)

    conn
    |> put_flash(:info, "Image has been approved.")
    |> moderation_log(details: &log_details/3, data: image)
    |> redirect(to: Routes.image_path(conn, :show, image))
  end

  defp log_details(conn, _action, image) do
    %{body: "Approved image #{image.id}", subject_path: Routes.image_path(conn, :show, image)}
  end
end
