defmodule PhilomenaWeb.Api.Json.Search.ReverseController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageReverse
  alias PhilomenaWeb.ImageJson

  plug :set_scraper_cache
  plug PhilomenaWeb.ScraperPlug, [params_key: "image", params_name: "image"]

  def create(conn, %{"image" => image_params}) do
    images =
      image_params
      |> Map.put("distance", conn.params["distance"])
      |> ImageReverse.images()
      |> Enum.map(&ImageJson.as_json(conn, &1))

    conn
    |> json(%{images: images})
  end

  defp set_scraper_cache(conn, _opts) do

    params =
      conn.params
      |> Map.put("image", %{})
      |> Map.put("distance", normalize_dist(conn.params))
      |> Map.put("scraper_cache", conn.params["url"])

    %{conn | params: params}
  end

  defp normalize_dist(%{"distance" => distance}) do
    "0" <> distance
    |> Float.parse()
    |> elem(0)
    |> Float.to_string()
  end
  defp normalize_dist(_dist), do: "0.25"
end
