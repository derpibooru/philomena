defmodule PhilomenaWeb.Image.FavoritesController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image

  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true, preload: [faves: :user]

  def index(conn, _params) do
    render(conn, "index.html", layout: false, image: conn.assigns.image)
  end
end