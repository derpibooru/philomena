defmodule PhilomenaWeb.ImageController do
  use PhilomenaWeb, :controller

  alias Philomena.{Images, Images.Image}
  import Ecto.Query

  plug ImageFilter

  def index(conn, _params) do
    query = conn.assigns[:compiled_filter]

    images =
      Image.search_records(
        %{
          query: %{bool: %{must_not: query}},
          sort: %{created_at: :desc}
        },
        Image |> preload(:tags)
      )

    render(conn, "index.html", images: images)
  end

  def show(conn, %{"id" => id}) do
    image = Images.get_image!(id)
    render(conn, "show.html", image: image)
  end
end
