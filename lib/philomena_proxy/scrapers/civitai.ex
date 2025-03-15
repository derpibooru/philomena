defmodule PhilomenaProxy.Scrapers.Civitai do
  @moduledoc false

  alias PhilomenaProxy.Scrapers.Scraper
  alias PhilomenaProxy.Scrapers

  @behaviour Scraper

  @url_regex ~r|\Ahttps?://(?:www\.)?civitai\.com/posts/([\d]+)/?|

  @spec can_handle?(URI.t(), String.t()) :: boolean()
  def can_handle?(_uri, url) do
    String.match?(url, @url_regex)
  end

  @spec scrape(URI.t(), Scrapers.url()) :: Scrapers.scrape_result()
  def scrape(_uri, url) do
    [post_id] = Regex.run(@url_regex, url, capture: :all_but_first)

    api_url = "https://api.civitai.com/v1/images?postId=#{post_id}&nsfw=X"
    {:ok, %{status: 200, body: body}} = PhilomenaProxy.Http.get(api_url)

    json = Jason.decode!(body)

    case json["items"] do
      [] ->
        %{
          source_url: url,
          author_name: "",
          description: "",
          images: []
        }

      items ->
        username = hd(items)["username"]

        images =
          Enum.map(items, fn item ->
            image_url = item["url"]

            %{
              url: image_url,
              camo_url: PhilomenaProxy.Camo.image_url(image_url)
            }
          end)

        %{
          source_url: url,
          author_name: username,
          description: "",
          images: images
        }
    end
  end
end
