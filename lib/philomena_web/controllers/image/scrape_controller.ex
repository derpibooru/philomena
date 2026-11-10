defmodule PhilomenaWeb.Image.ScrapeController do
  use PhilomenaWeb, :controller

  alias PhilomenaProxy.Scrapers

  def create(conn, params) do
    url =
      params
      |> Map.get("url")
      |> to_string()
      |> String.trim()

    cond do
      url == "" ->
        scrape_error(conn, "A URL must be provided.")

      is_nil(URI.parse(url).host) ->
        scrape_error(conn, "The URL is invalid.")

      true ->
        case Scrapers.scrape!(url) do
          nil -> scrape_error(conn, "No images found at that URL.")
          result -> json(conn, result)
        end
    end
  end

  defp scrape_error(conn, message) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: [message]})
  end
end
