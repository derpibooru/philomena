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

    image_id
    |> load_image()
    |> oembed_image(conn)
  end

  defp load_image(nil), do: nil

  defp load_image(id) do
    Image
    |> where(id: ^id, hidden_from_users: false)
    |> preload([:user, :sources, tags: :aliases])
    |> Repo.one()
  end

  defp oembed_image(nil, conn), do: oembed_error(conn)
  defp oembed_image(image, conn), do: render(conn, "show.json", image: image)

  defp oembed_error(conn) do
    conn
    |> Plug.Conn.put_status(:not_found)
    |> render("error.json")
  end
end
