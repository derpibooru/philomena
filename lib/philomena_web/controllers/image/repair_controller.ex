defmodule PhilomenaWeb.Image.RepairController do
  use PhilomenaWeb, :controller

  alias Philomena.Images

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, params) do
    with {:ok, image} <- Images.create_image_repair(conn.assigns.actor, params["image_id"]) do
      conn
      |> put_flash(:info, "Repair job enqueued.")
      |> redirect(to: ~p"/images/#{image}")
    end
  end
end
