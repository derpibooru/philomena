defmodule PhilomenaWeb.Search.ReverseController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageReverse

  plug PhilomenaWeb.ScraperCachePlug
  plug PhilomenaWeb.ScraperPlug, params_key: "image", params_name: "image"

  def index(conn, params) do
    create(conn, params)
  end

  def create(conn, %{"image" => image_params}) when is_map(image_params) do
    images = ImageReverse.images(image_params)

    render(conn, "index.html", title: "Reverse Search", images: images)
  end

  def create(conn, _params) do
    render(conn, "index.html", title: "Reverse Search", images: nil)
  end
end
