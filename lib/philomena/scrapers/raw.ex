defmodule Philomena.Scrapers.Raw do
  @mime_types ["image/gif", "image/jpeg", "image/png", "image/svg", "image/svg+xml", "video/webm"]

  @spec can_handle?(URI.t(), String.t()) :: true | false
  def can_handle?(_uri, url) do
    Philomena.Http.head(url)
    |> case do
      {:ok, %Tesla.Env{status: 200, headers: headers}} ->
        headers
        |> Enum.any?(fn {k, v} ->
          String.downcase(k) == "content-type" and String.downcase(v) in @mime_types
        end)

      _ ->
        false
    end
  end

  def scrape(_uri, url) do
    %{
      source_url: url,
      images: [
        %{
          url: url,
          camo_url: Camo.Image.image_url(url)
        }
      ]
    }
  end
end
