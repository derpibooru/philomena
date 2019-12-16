defmodule PhilomenaWeb.Api.Json.Search.ReverseController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageReverse
  alias PhilomenaWeb.ImageJson

  plug :set_scraper_cache
  plug PhilomenaWeb.ScraperPlug, [params_key: "image", params_name: "image"]

  def create(conn, %{"image" => image_params}) do
    images =
      image_params
      |> ImageReverse.images()
      |> Enum.map(&ImageJson.as_json(conn, &1))

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
