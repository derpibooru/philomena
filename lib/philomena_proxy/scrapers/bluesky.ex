defmodule PhilomenaProxy.Scrapers.Bluesky do
  @moduledoc false

  alias PhilomenaProxy.Scrapers.Scraper
  alias PhilomenaProxy.Scrapers

  @behaviour Scraper

  @url_regex ~r|https://bsky\.app/profile/([^/]+)/post/([^/?#]+)|
  @fullsize_image_regex ~r|.*/img/feed_fullsize/plain/([^/]+)/([^@]+).*|
  @blob_image_url_pattern "https://bsky.social/xrpc/com.atproto.sync.getBlob/?did=\\1&cid=\\2"

  @spec can_handle?(URI.t(), String.t()) :: boolean()
  def can_handle?(_uri, url) do
    String.match?(url, @url_regex)
  end

  @spec scrape(URI.t(), Scrapers.url()) :: Scrapers.scrape_result()
  def scrape(_uri, url) do
    [handle, id] = Regex.run(@url_regex, url, capture: :all_but_first)

    did =
      if String.starts_with?(handle, "did:") do
        handle
      else
        api_url_resolve_handle =
          "https://public.api.bsky.app/xrpc/com.atproto.identity.resolveHandle?handle=#{handle}"

        PhilomenaProxy.Http.get(api_url_resolve_handle) |> json!() |> Map.fetch!(:did)
      end

    api_url_get_posts =
      "https://public.api.bsky.app/xrpc/app.bsky.feed.getPosts?uris=at://#{did}/app.bsky.feed.post/#{id}"

    post_json = PhilomenaProxy.Http.get(api_url_get_posts) |> json!() |> Map.fetch!(:posts) |> hd

    %{
      source_url: url,
      author_name: post_json["author"]["handle"],
      description: post_json["record"]["text"],
      images:
        post_json["embed"]["images"]
        |> Enum.map(
          &%{
            url: String.replace(&1["fullsize"], @fullsize_image_regex, @blob_image_url_pattern),
            camo_url: PhilomenaProxy.Camo.image_url(&1["thumb"])
          }
        )
    }
  end

  defp json!({:ok, %{body: body, status: 200}}), do: Jason.decode!(body)
end
