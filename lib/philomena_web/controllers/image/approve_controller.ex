defmodule PhilomenaWeb.Image.ApproveController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images

  plug PhilomenaWeb.CanaryMapPlug, create: :approve
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true
  plug :verify_not_approved

  def create(conn, _params) do
    image = conn.assigns.image

    {:ok, _comment} = Images.approve_image(image)

    conn
    |> put_flash(:info, "Image has been approved.")
    |> moderation_log(details: &log_details/2, data: image)
    |> redirect(to: ~p"/admin/approvals")
  end

  defp verify_not_approved(conn, _opts) do
    if conn.assigns.image.approved do
      conn
      |> put_flash(:error, "Someone else already approved this image.")
      |> redirect(to: ~p"/admin/approvals")
      |> halt()
    else
      conn
    end
  end

  defp log_details(_action, image) do
    %{body: "Approved image #{image.id}", subject_path: ~p"/images/#{image}"}
  end
end
