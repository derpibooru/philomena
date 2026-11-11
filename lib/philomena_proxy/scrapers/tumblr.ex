defmodule PhilomenaProxy.Scrapers.Tumblr do
  @moduledoc false

  alias PhilomenaProxy.Scrapers.Scraper
  alias PhilomenaProxy.Scrapers

  @behaviour Scraper

  @url_regex ~r|\Ahttps?://(?:.*)/(?:image\|post)/(\d+)(?:\z\|[/?#])|
  # Captures the path segments shared by every size of one image, then the width.
  @media_regex ~r|https?://(?:\d+\.)?media\.tumblr\.com/([a-f\d]+/[a-f\d]+-[a-f\d]+)/s(\d+)x\d+/[a-f\d]+\.(?:png\|jpe?g\|gif)|i
  @size_regex ~r|_(\d+)(\..+)\z|
  @sizes [1280, 540, 500, 400, 250, 100, 75]
  @tumblr_ranges [
    InetCidr.parse_cidr!("66.6.32.0/24"),
    InetCidr.parse_cidr!("66.6.33.0/24"),
    InetCidr.parse_cidr!("66.6.44.0/24"),
    InetCidr.parse_cidr!("74.114.152.0/24"),
    InetCidr.parse_cidr!("74.114.153.0/24"),
    InetCidr.parse_cidr!("74.114.154.0/24"),
    InetCidr.parse_cidr!("74.114.155.0/24")
  ]

  @spec can_handle?(URI.t(), String.t()) :: true | false
  def can_handle?(uri, url) do
    String.match?(url, @url_regex) and tumblr_domain?(uri.host)
  end

  @spec scrape(URI.t(), Scrapers.url()) :: Scrapers.scrape_result() | nil
  def scrape(uri, url) do
    [post_id] = Regex.run(@url_regex, url, capture: :all_but_first)

    api_url =
      "https://api.tumblr.com/v2/blog/#{uri.host}/posts/photo?id=#{post_id}&api_key=#{tumblr_api_key()}"

    PhilomenaProxy.Http.get(api_url)
    |> json!()
    |> process_response!()
  end

  defp json!({:ok, %{body: body, status: 200}}),
    do: JSON.decode!(body)

  defp process_response!(%{"response" => %{"posts" => [post | _rest]}}),
    do: process_post(post)

  defp process_post(%{"type" => "photo"} = post) do
    images =
      post["photos"]
      |> Enum.map(fn photo ->
        image = upsize(photo["original_size"]["url"])

        %{"url" => preview} =
          Enum.find(photo["alt_sizes"], &(&1["width"] == 400)) || %{"url" => image}

        %{url: image, camo_url: PhilomenaProxy.Camo.image_url(preview)}
      end)

    add_meta(post, images)
  end

  defp process_post(%{"type" => "text"} = post),
    do: add_meta(post, inline_images(post["body"]))

  defp process_post(%{"type" => "answer"} = post),
    do: add_meta(post, inline_images(post["answer"]))

  defp process_post(_post), do: nil

  # Inline images appear once per srcset size; keep the widest of each,
  # in order of first appearance.
  defp inline_images(html) when is_binary(html) do
    matches = Regex.scan(@media_regex, html)

    widest =
      Enum.reduce(matches, %{}, fn [url, image, width], acc ->
        candidate = {String.to_integer(width), url}
        Map.update(acc, image, candidate, &max(&1, candidate))
      end)

    matches
    |> Enum.map(fn [_url, image, _width] -> image end)
    |> Enum.uniq()
    |> Enum.map(fn image ->
      {_width, url} = widest[image]
      %{url: url, camo_url: PhilomenaProxy.Camo.image_url(url)}
    end)
  end

  defp inline_images(_html), do: []

  defp upsize(image_url) do
    @sizes
    |> Enum.map(&String.replace(image_url, @size_regex, "_#{&1}\\2"))
    |> Enum.find(&url_ok?/1)
  end

  defp url_ok?(url) do
    match?({:ok, %{status: 200}}, PhilomenaProxy.Http.head(url))
  end

  defp add_meta(post, images) do
    source = post["post_url"]
    author = post["blog_name"]
    description = post["summary"]

    %{
      source_url: source,
      author_name: author,
      description: description,
      images: images
    }
  end

  defp tumblr_domain?(host) do
    host
    |> String.to_charlist()
    |> :inet_res.lookup(:in, :a)
    |> case do
      [address | _rest] ->
        Enum.any?(@tumblr_ranges, &InetCidr.contains?(&1, address))

      _ ->
        false
    end
  end

  defp tumblr_api_key do
    Application.get_env(:philomena, :tumblr_api_key)
  end
end
