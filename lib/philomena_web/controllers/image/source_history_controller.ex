defmodule PhilomenaWeb.Image.SourceHistoryController do
  use PhilomenaWeb, :controller

  alias Philomena.Images

  action_fallback PhilomenaWeb.FallbackController

  def delete(conn, params) do
    with {:ok, image} <-
           Images.delete_image_source_history(conn.assigns.actor, params["image_id"]) do
      conn
      |> put_flash(:info, "Successfully deleted source history.")
      |> redirect(to: ~p"/images/#{image}")
    end
  end
end
