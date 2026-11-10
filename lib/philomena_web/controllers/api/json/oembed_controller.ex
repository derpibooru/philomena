defmodule PhilomenaWeb.Api.Json.OembedController do
  use PhilomenaWeb, :controller

  alias Philomena.Images
  import PhilomenaWeb.Api.Json.NotFound

  # CDN image URLs always embed the image id directly after a
  # YYYY/M/D date prefix:
  #
  #   /img/YYYY/M/D/<id>/<version>.<ext>          (thumbnails)
  #   /img/YYYY/M/D/<id>-<key>/<version>.<ext>    (hidden images)
  #   /img/view/YYYY/M/D/<id>.<ext>               (short view/download URLs)
  #   /img/view/YYYY/M/D/<id>__<tag-slugs>.<ext>  (verbose view/download URLs)
  #
  # Anchoring on the full date prefix guarantees a date component can
  # never be mistaken for an image id.
  @cdn_regex ~r/\/img\/(?:view\/|download\/)?\d{4}\/\d{1,2}\/\d{1,2}\/(\d+)[.\/_-]/
  @img_regex ~r/\/(\d+)/

  def index(conn, %{"url" => url}) when is_binary(url) do
    url
    |> URI.parse()
    |> try_oembed(conn)
  end

  def index(conn, _params), do: not_found(conn)

  # A URL with no path at all (e.g. `https://example.com`) parses to a nil path.
  defp try_oembed(%{path: path}, conn) when is_binary(path) do
    case Images.show_api_image(conn.assigns.actor, extract_image_id(path)) do
      {:ok, %{hidden_from_users: false} = image} -> render(conn, "show.json", image: image)
      _error -> not_found(conn)
    end
  end

  defp try_oembed(_parsed, conn), do: not_found(conn)

  defp extract_image_id(path) do
    cdn = Regex.run(@cdn_regex, path, capture: :all_but_first)

    cond do
      cdn ->
        hd(cdn)

      # A CDN-shaped path without a recognizable id must not fall through
      # to the site regex, which would match a date component instead.
      String.contains?(path, "/img/") ->
        nil

      true ->
        case Regex.run(@img_regex, path, capture: :all_but_first) do
          [id] -> id
          nil -> nil
        end
    end
  end
end
