defmodule Philomena.Scrapers.Deviantart do
  @image_regex ~r|<link data-rh="true" rel="preload" href="([^"]*)" as="image"/>|
  @source_regex ~r|<link data-rh="true" rel="canonical" href="([^"]*)"/>|
  @artist_regex ~r|https://www.deviantart.com/([^/]*)/art|
  @serial_regex ~r|https://www.deviantart.com/(?:.*?)-(\d+)\z|
  @cdnint_regex ~r|(https://images-wixmp-[0-9a-f]+.wixmp.com)(?:/intermediary)?/f/([^/]*)/([^/?]*)|
  @png_regex ~r|(https://[0-9a-z\-\.]+(?:/intermediary)?/f/[0-9a-f\-]+/[0-9a-z\-]+\.png/v1/fill/[0-9a-z_,]+/[0-9a-z_\-]+)(\.png)(.*)|
  @jpg_regex ~r|(https://[0-9a-z\-\.]+(?:/intermediary)?/f/[0-9a-f\-]+/[0-9a-z\-]+\.jpg/v1/fill/w_[0-9]+,h_[0-9]+,q_)([0-9]+)(,[a-z]+\/[a-z0-6_\-]+\.jpe?g.*)|

  @spec can_handle?(URI.t(), String.t()) :: true | false
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
  def scrape(_uri, url) do
    url
    |> follow_redirect(2)
    |> extract_data!()
    |> try_intermediary_hires!()
    |> try_new_hires!()
    |> try_old_hires!()
  end

  defp extract_data!({:ok, %Tesla.Env{body: body, status: 200}}) do
    [image] = Regex.run(@image_regex, body, capture: :all_but_first)
    [source] = Regex.run(@source_regex, body, capture: :all_but_first)
    [artist] = Regex.run(@artist_regex, source, capture: :all_but_first)

    %{
      source_url: source,
      author_name: artist,
      images: [
        %{
          url: image,
          camo_url: Camo.Image.image_url(image)
        }
      ]
    }
  end

  defp try_intermediary_hires!(%{images: [image]} = data) do
    with [domain, object_uuid, object_name] <-
           Regex.run(@cdnint_regex, image.url, capture: :all_but_first),
         built_url <- "#{domain}/intermediary/f/#{object_uuid}/#{object_name}",
         {:ok, %Tesla.Env{status: 200}} <- Philomena.Http.head(built_url) do
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

  defp try_old_hires!(%{source_url: source, images: [image]} = data) do
    [serial] = Regex.run(@serial_regex, source, capture: :all_but_first)

    base36 =
      serial
      |> String.to_integer()
      |> Integer.to_string(36)
      |> String.downcase()

    built_url = "http://orig01.deviantart.net/x_by_x-d#{base36}.png"

    case Philomena.Http.get(built_url) do
      {:ok, %Tesla.Env{status: 301, headers: headers}} ->
        # Location header provides URL of high res image.
        {_location, link} = Enum.find(headers, fn {header, _val} -> header == "location" end)

        %{
          data
          | images: [
              %{
                url: link,
                camo_url: image.camo_url
              }
            ]
        }

      _ ->
        # Nothing to be found here, move along...
        data
    end
  end

  # Workaround for benoitc/hackney#273
  defp follow_redirect(_url, 0), do: nil

  defp follow_redirect(url, max_times) do
    case Philomena.Http.get(url) do
      {:ok, %Tesla.Env{headers: headers, status: code}} when code in [301, 302] ->
        location = Enum.find_value(headers, &location_header/1)
        follow_redirect(location, max_times - 1)

      response ->
        response
    end
  end

  defp location_header({"Location", location}), do: location
  defp location_header({"location", location}), do: location
  defp location_header(_), do: nil
end
