defmodule PhilomenaWeb.Image.FeatureController do
  use PhilomenaWeb, :controller

  alias Philomena.Images

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"image_id" => image_id}) do
    case Images.create_image_feature(conn.assigns.actor, image_id) do
      {:ok, _feature} ->
        conn
        |> put_flash(:info, "Image marked as featured image.")
        |> redirect(to: ~p"/images/#{image_id}")

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_flash(:error, "Cannot feature a deleted image.")
        |> redirect(to: ~p"/images/#{image_id}")

      error ->
        error
    end
  end
end
