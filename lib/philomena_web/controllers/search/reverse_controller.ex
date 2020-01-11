defmodule PhilomenaWeb.Search.ReverseController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageReverse

  plug :set_scraper_cache
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

  defp set_scraper_cache(conn, _opts) do
    params =
      conn.params
      |> Map.put_new("image", %{})
      |> Map.put_new("scraper_cache", conn.params["url"])
      |> Map.put("distance", normalize_dist(conn.params))

    %{conn | params: params}
  end

  defp normalize_dist(%{"distance" => distance}) do
    ("0" <> distance)
    |> Float.parse()
    |> elem(0)
    |> Float.to_string()
  end

  defp normalize_dist(_dist), do: "0.25"
end
