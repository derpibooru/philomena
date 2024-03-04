defmodule Philomena.Scrapers.Twitter do
  @url_regex ~r|\Ahttps?://(?:mobile\.)?twitter.com/([A-Za-z\d_]+)/status/([\d]+)/?|

  @spec can_handle?(URI.t(), String.t()) :: true | false
  def can_handle?(_uri, url) do
    String.match?(url, @url_regex)
  end

  def scrape(_uri, url) do
    [user, status_id] = Regex.run(@url_regex, url, capture: :all_but_first)

    image_url = "https://d.fxtwitter.com/#{user}/status/#{status_id}.jpg"

    {:ok, %Tesla.Env{status: 200}} = Philomena.Http.head(image_url)

    %{
      source_url: "https://twitter.com/#{user}/status/#{status_id}",
      author_name: user,
      images: [
        %{
          url: image_url,
          camo_url: Camo.Image.image_url(image_url)
        }
      ]
    }
  end
end
