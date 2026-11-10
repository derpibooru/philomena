defmodule PhilomenaWeb.Image.FaveController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"image_id" => image_id}) do
    with {:ok, image} <- Images.create_image_fave(conn.assigns.actor, image_id) do
      json(conn, Image.interaction_data(image))
    end
  end

  def delete(conn, %{"image_id" => image_id}) do
    with {:ok, image} <- Images.delete_image_fave(conn.assigns.actor, image_id) do
      json(conn, Image.interaction_data(image))
    end
  end
end
