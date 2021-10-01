defmodule Philomena.Scrapers.Tumblr do
  @url_regex ~r|\Ahttps?://(?:.*)/(?:image\|post)/(\d+)(?:\z\|[/?#])|
  @media_regex ~r|https?://(?:\d+\.)?media\.tumblr\.com/[a-f\d]+/[a-f\d]+-[a-f\d]+/s\d+x\d+/[a-f\d]+\.(?:png\|jpe?g\|gif)|i
  @size_regex ~r|_(\d+)(\..+)\z|
  @sizes [1280, 540, 500, 400, 250, 100, 75]
  @tumblr_ranges [
    InetCidr.parse("66.6.32.0/24"),
    InetCidr.parse("66.6.33.0/24"),
    InetCidr.parse("66.6.44.0/24"),
    InetCidr.parse("74.114.152.0/24"),
    InetCidr.parse("74.114.153.0/24"),
    InetCidr.parse("74.114.154.0/24"),
    InetCidr.parse("74.114.155.0/24")
  ]

  @spec can_handle?(URI.t(), String.t()) :: true | false
  def can_handle?(uri, url) do
    String.match?(url, @url_regex) and tumblr_domain?(uri.host)
  end

  def scrape(uri, url) do
    [post_id] = Regex.run(@url_regex, url, capture: :all_but_first)

    api_url =
      "https://api.tumblr.com/v2/blog/#{uri.host}/posts/photo?id=#{post_id}&api_key=#{
        tumblr_api_key()
      }"

    Philomena.Http.get(api_url)
    |> json!()
    |> process_response!()
  end

  defp json!({:ok, %Tesla.Env{body: body, status: 200}}),
    do: Jason.decode!(body)

  defp process_response!(%{"response" => %{"posts" => [post | _rest]}}),
    do: process_post!(post)

  defp process_post!(%{"type" => "photo"} = post) do
    images =
      post["photos"]
      |> Enum.map(fn photo ->
        image = upsize(photo["original_size"]["url"])

        %{"url" => preview} =
          Enum.find(photo["alt_sizes"], &(&1["width"] == 400)) || %{"url" => image}

        %{url: image, camo_url: Camo.Image.image_url(preview)}
      end)

    add_meta(post, images)
  end

  defp process_post!(%{"type" => "text"} = post) do
    images =
      @media_regex
      |> Regex.scan(post["body"])
      |> Enum.map(fn [url | _captures] ->
        %{url: url, camo_url: Camo.Image.image_url(url)}
      end)

    add_meta(post, images)
  end

  defp upsize(image_url) do
    @sizes
    |> Enum.map(&String.replace(image_url, @size_regex, "_#{&1}\\2"))
    |> Enum.find(&url_ok?/1)
  end

  defp url_ok?(url) do
    match?({:ok, %Tesla.Env{status: 200}}, Philomena.Http.head(url))
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
