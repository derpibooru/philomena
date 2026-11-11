defmodule PhilomenaProxy.Scrapers.Scraper do
  @moduledoc false

  alias PhilomenaProxy.Scrapers

  # Return whether the given URL can be parsed by the scraper
  @callback can_handle?(URI.t(), Scrapers.url()) :: boolean()

  # Collect upload information from the URL, or nil when it has none
  @callback scrape(URI.t(), Scrapers.url()) :: Scrapers.scrape_result() | nil
end
