defmodule PhilomenaProxy.Scrapers.Raw do
  @moduledoc false

  alias PhilomenaProxy.Scrapers.Scraper
  alias PhilomenaProxy.Scrapers

  @behaviour Scraper

  @mime_types ["image/gif", "image/jpeg", "image/png", "image/svg", "image/svg+xml", "video/webm"]

  @spec can_handle?(URI.t(), String.t()) :: boolean()
  def can_handle?(_uri, url) do
    PhilomenaProxy.Http.head(url)
    |> case do
      {:ok, %{status: 200, headers: headers}} ->
        headers
        |> Enum.any?(fn {k, v} ->
          String.downcase(k) == "content-type" and String.downcase(v) in @mime_types
        end)

      _ ->
        false
    end
  end

  @spec scrape(URI.t(), Scrapers.url()) :: Scrapers.scrape_result()
  def scrape(_uri, url) do
    %{
      source_url: url,
      author_name: "",
      description: "",
      images: [
        %{
          url: url,
          camo_url: PhilomenaProxy.Camo.image_url(url)
        }
      ]
    }
  end
end
