defmodule PhilomenaWeb.Image.ApproveController do
  use PhilomenaWeb, :controller

  alias Philomena.Images

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, params) do
    case Images.create_image_approve(conn.assigns.actor, params["image_id"]) do
      {:ok, _image} ->
        conn
        |> put_flash(:info, "Image has been approved.")
        |> redirect(to: ~p"/admin/approvals")

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_flash(:error, "Someone else already approved this image.")
        |> redirect(to: ~p"/admin/approvals")

      error ->
        error
    end
  end
end
