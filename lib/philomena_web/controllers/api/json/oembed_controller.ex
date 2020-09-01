defmodule PhilomenaWeb.Api.Json.OembedController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Repo
  import Ecto.Query

  @cdn_regex ~r/\/img\/.*\/(\d+)(\.|[\/_][_\w])/
  @img_regex ~r/\/(\d+)/

  def index(conn, %{"url" => url}) do
    parsed = URI.parse(url)

    try_oembed(conn, parsed)
  end

  def index(conn, _params), do: oembed_error(conn)

  defp try_oembed(conn, %{path: path}) do
    cdn = Regex.run(@cdn_regex, path, capture: :all_but_first)
    img = Regex.run(@img_regex, path, capture: :all_but_first)

    image_id =
      cond do
        cdn -> hd(cdn)
        img -> hd(img)
        true -> nil
      end

    load_image(image_id)
    |> oembed_image(conn)
  end

  defp load_image(nil), do: nil

  defp load_image(id) do
    Image
    |> where(id: ^id, hidden_from_users: false)
    |> preload([:tags, :user])
    |> Repo.one()
  end

  defp oembed_image(nil, conn), do: oembed_error(conn)
  defp oembed_image(image, conn), do: json(conn, oembed_json(image))

  defp oembed_error(conn) do
    conn
    |> Plug.Conn.put_status(:not_found)
    |> json(%{error: "couldn't find an image"})
  end

  defp oembed_json(image) do
    %{
      version: "1.0",
      type: "photo",
      title: "##{image.id} - #{image.tag_list_cache} - YourBooruName",
      author_url: image.source_url || "",
      author_name: artist_tags(image.tags),
      provider_name: "YourBooruName",
      provider_url: PhilomenaWeb.Endpoint.url(),
      cache_age: 7200,
      booru_id: image.id,
      booru_score: image.score,
      booru_comments: image.comments_count,
      booru_tags: Enum.map(image.tags, & &1.name)
    }
  end

  defp artist_tags(tags) do
    tags
    |> Enum.filter(&(&1.namespace == "artist"))
    |> Enum.map_join(", ", & &1.name_in_namespace)
  end
end
