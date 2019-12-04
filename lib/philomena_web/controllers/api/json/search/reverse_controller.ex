defmodule PhilomenaWeb.Api.Json.Search.ReverseController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageReverse

  plug :set_scraper_cache
  plug PhilomenaWeb.ScraperPlug, [params_key: "image", params_name: "image"]

  def create(conn, %{"image" => image_params}) do
    images = ImageReverse.images(image_params)

    conn
    |> json(%{images: images})
  end

  defp set_scraper_cache(conn, _opts) do
    params =
      conn.params
      |> Map.put("image", %{})
      |> Map.put("scraper_cache", conn.params["url"])

    %{conn | params: params}
  end
end