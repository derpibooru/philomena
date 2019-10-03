defmodule PhilomenaWeb.ImageController do
  use PhilomenaWeb, :controller

  alias Philomena.{Images.Image}
  import Ecto.Query

  plug ImageFilter
  plug :load_and_authorize_resource, model: Image, only: :show, preload: :tags

  def index(conn, _params) do
    query = conn.assigns.compiled_filter

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

  def show(conn, %{"id" => _id}) do
    render(conn, "show.html", image: conn.assigns.image)
  end
end
