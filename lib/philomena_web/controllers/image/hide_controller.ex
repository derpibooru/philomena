defmodule PhilomenaWeb.Image.HideController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, params) do
    with {:ok, image} <- Images.create_image_user_hide(conn.assigns.actor, params["image_id"]) do
      json(conn, Image.interaction_data(image))
    end
  end

  def delete(conn, params) do
    with {:ok, image} <- Images.delete_image_user_hide(conn.assigns.actor, params["image_id"]) do
      json(conn, Image.interaction_data(image))
    end
  end
end
