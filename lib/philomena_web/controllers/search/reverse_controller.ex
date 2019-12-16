defmodule PhilomenaWeb.Search.ReverseController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageReverse

  plug PhilomenaWeb.ScraperPlug, [params_key: "image", params_name: "image"] when action in [:create]

  def index(conn, _params) do
    render(conn, "index.html", title: "Reverse Search", images: nil)
  end

  def create(conn, %{"image" => image_params}) do
    images = ImageReverse.images(image_params)

    conn
    |> render("index.html", title: "Reverse Search", images: images)
  end
end
