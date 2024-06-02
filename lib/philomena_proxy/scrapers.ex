defmodule PhilomenaProxy.Scrapers do
  @moduledoc """
  Scrape utilities to facilitate uploading media from other websites.
  """

  # The URL to fetch, as a string.
  @type url :: String.t()

  # An individual image in a list associated with a scrape result.
  @type image_result :: %{
          url: url(),
          camo_url: url()
        }

  # Result of a successful scrape.
  @type scrape_result :: %{
          source_url: url(),
          description: String.t() | nil,
          author_name: String.t() | nil,
          images: [image_result()]
        }

  @scrapers [
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

    @scrapers
    |> Enum.find(& &1.can_handle?(uri, url))
    |> wrap()
    |> Enum.map(& &1.scrape(uri, url))
    |> unwrap()
  end

  defp wrap(nil), do: []
  defp wrap(res), do: [res]

  defp unwrap([result]), do: result
  defp unwrap(_result), do: nil
end
