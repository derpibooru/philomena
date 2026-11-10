defmodule PhilomenaWeb.Gallery.ReadController do
  use PhilomenaWeb, :controller

  alias Philomena.Galleries

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, params) do
    with {:ok, _gallery} <-
           Galleries.create_gallery_read(conn.assigns.actor, params["gallery_id"]) do
      send_resp(conn, :ok, "")
    end
  end
end
