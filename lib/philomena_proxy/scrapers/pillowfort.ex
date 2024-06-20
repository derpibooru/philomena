defmodule PhilomenaProxy.Scrapers.Pillowfort do
  @moduledoc false

  alias PhilomenaProxy.Scrapers.Scraper
  alias PhilomenaProxy.Scrapers

  @behaviour Scraper

  @url_regex ~r|\Ahttps?://www\.pillowfort\.social/posts/([0-9]+)|

  @spec can_handle?(URI.t(), String.t()) :: boolean()
  def can_handle?(_uri, url) do
    String.match?(url, @url_regex)
  end

  @spec scrape(URI.t(), Scrapers.url()) :: Scrapers.scrape_result()
  def scrape(_uri, url) do
    [post_id] = Regex.run(@url_regex, url, capture: :all_but_first)

    api_url = "https://www.pillowfort.social/posts/#{post_id}/json"

    PhilomenaProxy.Http.get(api_url)
    |> json!()
    |> process_response!(url)
  end

  defp json!({:ok, %{body: body, status: 200}}),
    do: Jason.decode!(body)

  defp process_response!(post_json, url) do
    images =
      post_json["media"]
      |> Enum.map(
        &%{
          url: &1["url"],
          camo_url: PhilomenaProxy.Camo.image_url(&1["small_image_url"])
        }
      )

    %{
      source_url: url,
      author_name: post_json["username"],
      description: Enum.join(title(post_json) ++ content(post_json), "\n\n---\n\n"),
      images: images
    }
  end

  defp title(%{"title" => title}) when title not in [nil, ""], do: [remove_html_tags(title)]
  defp title(_), do: []

  defp content(%{"content" => content}) when content not in [nil, ""],
    do: [remove_html_tags(content)]

  defp content(_), do: []

  defp remove_html_tags(text) do
    # The markup parser won't render these tags, so remove them
    String.replace(text, ~r|<.+?>|, "")
  end
end
