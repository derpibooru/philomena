defmodule PhilomenaProxy.Scrapers do
  @moduledoc """
  Scrape utilities to facilitate uploading media from other websites.
  """

  @typedoc "The URL to fetch, as a string."
  @type url :: String.t()

  @typedoc "An individual image in a list associated with a scrape result."
  @type image_result :: %{
          url: url(),
          camo_url: url()
        }

  @typedoc "Result of a successful scrape."
  @type scrape_result :: %{
          source_url: url(),
          description: String.t() | nil,
          author_name: String.t() | nil,
          images: [image_result()]
        }

  @scrapers [
    PhilomenaProxy.Scrapers.Bluesky,
    PhilomenaProxy.Scrapers.Civitai,
    PhilomenaProxy.Scrapers.Deviantart,
    PhilomenaProxy.Scrapers.Pillowfort,
    PhilomenaProxy.Scrapers.Twitter,
    PhilomenaProxy.Scrapers.Tumblr,
    PhilomenaProxy.Scrapers.Raw
  ]

  @doc """
  Scrape a URL for content.

  The scrape result is intended for serialization to JSON.

  ## Examples

      iex> PhilomenaProxy.Scrapers.scrape!("http://example.org/image-page")
      %{
        source_url: "http://example.org/image-page",
        description: "Test",
        author_name: "myself",
        images: [
          %{
            url: "http://example.org/image.png"
            camo_url: "http://example.net/UT2YIjkWDas6CQBmQcYlcNGmKfQ/aHR0cDovL2V4YW1wbGUub3JnL2ltY"
          }
        ]
      }

      iex> PhilomenaProxy.Scrapers.scrape!("http://example.org/nonexistent-path")
      nil

  """
  @spec scrape!(url()) :: scrape_result() | nil
  def scrape!(url) do
    uri = URI.parse(url)

    cond do
      is_nil(uri.host) ->
        # Scraping without a hostname doesn't make sense because the proxy cannot fetch it, and
        # some scrapers may test properties of the hostname.
        nil

      true ->
        # Find the first scraper which can handle the URL and process, or return nil
        Enum.find_value(@scrapers, nil, fn scraper ->
          scraper.can_handle?(uri, url) && scraper.scrape(uri, url)
        end)
    end
  end
end
