defmodule PhilomenaWeb.Image.FavoriteController do
  use PhilomenaWeb, :controller

  alias Philomena.Images

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, params) do
    with {:ok, {image, has_votes}} <-
           Images.list_image_faves(conn.assigns.actor, params["image_id"]) do
      render(conn, "index.html", layout: false, image: image, has_votes: has_votes)
    end
  end
end
