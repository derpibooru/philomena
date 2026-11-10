defmodule PhilomenaWeb.Image.TamperController do
  use PhilomenaWeb, :controller

  alias Philomena.Images

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, params) do
    with {:ok, image} <-
           Images.delete_user_vote(
             conn.assigns.actor,
             params["image_id"],
             params["user_id"]
           ) do
      conn
      |> put_flash(:info, "Vote removed.")
      |> redirect(to: ~p"/images/#{image}")
    end
  end
end
