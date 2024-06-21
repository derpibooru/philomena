defmodule PhilomenaProxy.Scrapers.Raw do
  @moduledoc false

  alias PhilomenaProxy.Scrapers.Scraper
  alias PhilomenaProxy.Scrapers

  @behaviour Scraper

  @mime_types ["image/gif", "image/jpeg", "image/png", "image/svg", "image/svg+xml", "video/webm"]

  @spec can_handle?(URI.t(), String.t()) :: boolean()
  def can_handle?(_uri, url) do
    with {:ok, %{status: 200, headers: headers}} <- PhilomenaProxy.Http.head(url),
         [type | _] <- headers["content-type"] do
      String.downcase(type) in @mime_types
    else
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
