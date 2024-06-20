defmodule PhilomenaProxy.Scrapers.Deviantart do
  @moduledoc false

  alias PhilomenaProxy.Scrapers.Scraper
  alias PhilomenaProxy.Scrapers

  @behaviour Scraper

  @image_regex ~r|data-rh="true" rel="preload" href="([^"]*)" as="image"|
  @source_regex ~r|rel="canonical" href="([^"]*)"|
  @artist_regex ~r|https://www.deviantart.com/([^/]*)/art|
  @cdnint_regex ~r|(https://images-wixmp-[0-9a-f]+.wixmp.com)(?:/intermediary)?/f/([^/]*)/([^/?]*)|
  @png_regex ~r|(https://[0-9a-z\-\.]+(?:/intermediary)?/f/[0-9a-f\-]+/[0-9a-z\-]+\.png/v1/fill/[0-9a-z_,]+/[0-9a-z_\-]+)(\.png)(.*)|
  @jpg_regex ~r|(https://[0-9a-z\-\.]+(?:/intermediary)?/f/[0-9a-f\-]+/[0-9a-z\-]+\.jpg/v1/fill/w_[0-9]+,h_[0-9]+,q_)([0-9]+)(,[a-z]+\/[a-z0-6_\-]+\.jpe?g.*)|

  @spec can_handle?(URI.t(), String.t()) :: boolean()
  def can_handle?(uri, _url) do
    String.ends_with?(uri.host, "deviantart.com")
  end

  # https://github.com/DeviantArt/DeviantArt-API/issues/153
  #
  # Note that Erlang (and by extension Elixir) do not have any sort of
  # reliable HTML/XML parsers that can accept untrusted input. As an example,
  # xmerl is vulnerable to almost every XML attack which has ever been
  # created, and also exposes the runtime to symbol DoS as an added bonus.
  #
  # So, regex it is. Eat dirt, deviantart. You don't deserve the respect
  # artists give you.
  @spec scrape(URI.t(), Scrapers.url()) :: Scrapers.scrape_result()
  def scrape(_uri, url) do
    url
    |> PhilomenaProxy.Http.get()
    |> extract_data!()
    |> try_intermediary_hires!()
    |> try_new_hires!()
  end

  defp extract_data!({:ok, %{body: body, status: 200}}) do
    [image] = Regex.run(@image_regex, body, capture: :all_but_first)
    [source] = Regex.run(@source_regex, body, capture: :all_but_first)
    [artist] = Regex.run(@artist_regex, source, capture: :all_but_first)

    %{
      source_url: source,
      author_name: artist,
      description: "",
      images: [
        %{
          url: image,
          camo_url: PhilomenaProxy.Camo.image_url(image)
        }
      ]
    }
  end

  defp try_intermediary_hires!(%{images: [image]} = data) do
    with [domain, object_uuid, object_name] <-
           Regex.run(@cdnint_regex, image.url, capture: :all_but_first),
         built_url <- "#{domain}/intermediary/f/#{object_uuid}/#{object_name}",
         {:ok, %{status: 200}} <- PhilomenaProxy.Http.head(built_url) do
      # This is the high resolution URL.
      %{
        data
        | images: [
            %{
              url: built_url,
              camo_url: image.camo_url
            }
          ]
      }
    else
      _ ->
        # Nothing to be found here, move along...
        data
    end
  end

  defp try_new_hires!(%{images: [image]} = data) do
    cond do
      String.match?(image.url, @png_regex) ->
        %{
          data
          | images: [
              %{
                url: String.replace(image.url, @png_regex, "\\1.png\\3"),
                camo_url: image.camo_url
              }
            ]
        }

      String.match?(image.url, @jpg_regex) ->
        %{
          data
          | images: [
              %{
                url: String.replace(image.url, @jpg_regex, "\\g{1}100\\3"),
                camo_url: image.camo_url
              }
            ]
        }

      true ->
        # Nothing to be found here, move along...
        data
    end
  end
end
