defmodule PhilomenaProxy.Scrapers.Bluesky do
  @moduledoc false

  alias PhilomenaProxy.Scrapers.Scraper
  alias PhilomenaProxy.Scrapers

  @behaviour Scraper

  @url_regex ~r|https://bsky\.app/profile/([^/]+)/post/(.+)|

  @spec can_handle?(URI.t(), String.t()) :: boolean()
  def can_handle?(_uri, url) do
    String.match?(url, @url_regex)
  end

  @spec scrape(URI.t(), Scrapers.url()) :: Scrapers.scrape_result()
  def scrape(_uri, url) do
    [handle, id] = Regex.run(@url_regex, url, capture: :all_but_first)

    api_url_resolve_handle = "https://public.api.bsky.app/xrpc/com.atproto.identity.resolveHandle?handle=#{handle}"
    did = PhilomenaProxy.Http.get(api_url_resolve_handle) |> json!() |> &1["did"]

    api_url_get_posts = "https://public.api.bsky.app/xrpc/app.bsky.feed.getPosts?uris=at://#{did}/app.bsky.feed.post/#{id}"
    post_json = PhilomenaProxy.Http.get(api_url_get_posts) |> json!() |> &1["posts"][0]

    %{
      source_url: url,
      author_name: post_json["author"]["handle"],
      description: post_json["record"]["text"],
      images: post_json["embed"]["images"] |> Enum.map(
        &%{
          url: &1["fullsize"],
          camo_url: PhilomenaProxy.Camo.image_url(&1["thumb"])
        }
      )
    }
  end
end
