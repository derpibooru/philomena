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

  The scrape result is intended for serialization to JSON. Returns nil when no
  scraper handles the URL, or when it is not an absolute http or https URL.

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
    case parse_url(url) do
      {:ok, uri} ->
        # Find the first scraper which can handle the URL and process, or return nil
        Enum.find_value(@scrapers, nil, fn scraper ->
          scraper.can_handle?(uri, url) && scraper.scrape(uri, url)
        end)

      :error ->
        nil
    end
  end

  @doc """
  Fetch a URL chosen from a scrape result, for use as an uploaded file.

  Returns `{:error, :invalid_url}` without making a request when the URL is
  not an absolute http or https URL.

  ## Examples

      iex> PhilomenaProxy.Scrapers.scrape_cached("http://example.org/image.png")
      {:ok, %Req.Response{status: 200, body: <<137, 80, 78, 71, ...>>}}

      iex> PhilomenaProxy.Scrapers.scrape_cached("/images/image.png")
      {:error, :invalid_url}

  """
  @spec scrape_cached(url()) :: PhilomenaProxy.Http.result() | {:error, :invalid_url}
  def scrape_cached(url) do
    case parse_url(url) do
      {:ok, _uri} -> PhilomenaProxy.Http.get(url)
      :error -> {:error, :invalid_url}
    end
  end

  # The proxy can only fetch absolute http(s) URLs, and some scrapers
  # test properties of the hostname.
  defp parse_url(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} = uri
      when scheme in ["http", "https"] and host not in [nil, ""] ->
        {:ok, uri}

      _uri ->
        :error
    end
  end

  defp parse_url(_url), do: :error
end
