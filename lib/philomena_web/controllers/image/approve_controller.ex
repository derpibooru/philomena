defmodule PhilomenaWeb.Image.ApproveController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images

  plug PhilomenaWeb.CanaryMapPlug, create: :approve
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true
  plug :verify_image_state

  def create(conn, _params) do
    image = conn.assigns.image

    {:ok, _comment} = Images.approve_image(image)

    conn
    |> put_flash(:info, "Image has been approved.")
    |> moderation_log(details: &log_details/2, data: image)
    |> redirect(to: ~p"/admin/approvals")
  end

  defp verify_image_state(conn, _opts) do
    image = conn.assigns.image

    cond do
      image.approved ->
        conn
        |> put_flash(:error, "Someone else already approved this image.")
        |> redirect(to: ~p"/admin/approvals")
        |> halt()

      image.hidden_from_users ->
        conn
        |> put_flash(:error, "Cannot approve a hidden image.")
        |> redirect(to: ~p"/admin/approvals")
        |> halt()

      true ->
        conn
    end
  end

  defp log_details(_action, image) do
    %{body: "Approved image #{image.id}", subject_path: ~p"/images/#{image}"}
  end
end
