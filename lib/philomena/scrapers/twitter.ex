defmodule Philomena.Scrapers.Twitter do
  @gt_regex ~r|decodeURIComponent\("gt=(\d+);|
  @url_regex ~r|\Ahttps?://(?:mobile\.)?twitter.com/([A-Za-z\d_]+)/status/([\d]+)/?|
  @script_regex ~r|="(https://abs.twimg.com/responsive-web/client-web(?:-legacy)?/main\.[\da-z]+\.js)"|
  @bearer_regex ~r|"(AAAAAAAAAAAAA[^"]*)"|

  @spec can_handle?(URI.t(), String.t()) :: true | false
  def can_handle?(_uri, url) do
    String.match?(url, @url_regex)
  end

  def scrape(_uri, url) do
    api_response!(url)
    |> extract_data()
  end

  defp extract_data(tweet) do
    images =
      tweet["entities"]["media"]
      |> Enum.map(
        &%{
          url: &1["media_url_https"] <> "?format=jpg&name=4096x4096",
          camo_url: Camo.Image.image_url(&1["media_url_https"])
        }
      )

    %{
      source_url: tweet["url"],
      author_name: tweet["user"],
      description: tweet["text"] || tweet["full_text"],
      images: images
    }
  end

  # We'd like to use the API anonymously. In order to do this, we need to
  # extract the anonymous bearer token. Fortunately, this is pretty easy
  # to identify in the minified mobile script source.
  def api_response!(url) do
    [user, status_id] = Regex.run(@url_regex, url, capture: :all_but_first)

    page_url = "https://twitter.com/#{user}/status/#{status_id}"

    api_url =
      "https://api.twitter.com/2/timeline/conversation/#{status_id}.json?tweet_mode=extended"

    url = "https://twitter.com/#{user}/status/#{status_id}"

    {gt, bearer} =
      Philomena.Http.get(page_url)
      |> extract_guest_token_and_bearer()

    {:ok, api_resp} =
      Philomena.Http.get(api_url, [{"Authorization", "Bearer #{bearer}"}, {"x-guest-token", gt}])

    api_resp
    |> Map.get(:body)
    |> Jason.decode!()
    |> Map.get("globalObjects")
    |> Map.get("tweets")
    |> Map.get(status_id)
    |> Map.put("user", user)
    |> Map.put("url", url)
  end

  defp extract_guest_token_and_bearer({:ok, %Tesla.Env{body: page}}) do
    [gt] = Regex.run(@gt_regex, page, capture: :all_but_first)
    [script | _] = Regex.run(@script_regex, page, capture: :all_but_first)

    {:ok, %{body: body}} = Philomena.Http.get(script)

    [bearer] = Regex.run(@bearer_regex, body, capture: :all_but_first)

    {gt, bearer}
  end
end
