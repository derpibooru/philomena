defmodule PhilomenaWeb.Image.ScrapeController do
  use PhilomenaWeb, :controller

  alias PhilomenaProxy.Scrapers

  def create(conn, params) do
    result =
      params
      |> Map.get("url")
      |> to_string()
      |> String.trim()
      |> Scrapers.scrape!()

    conn
    |> json(result)
  end
end
