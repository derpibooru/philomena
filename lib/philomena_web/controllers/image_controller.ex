defmodule PhilomenaWeb.ImageController do
  use PhilomenaWeb, :controller

  alias Philomena.{Images.Image, Comments.Comment}
  alias Philomena.Repo
  import Ecto.Query

  plug :load_and_authorize_resource, model: Image, only: :show, preload: [:tags, :user]

  def index(conn, _params) do
    query = conn.assigns.compiled_filter

    images =
      Image.search_records(
        %{
          query: %{bool: %{must_not: query}},
          sort: %{created_at: :desc}
        },
        Image |> preload([:tags, :user])
      )

    render(conn, "index.html", images: images)
  end

  def show(conn, %{"id" => _id}) do
    comments =
      Comment
      |> where(image_id: ^conn.assigns.image.id)
      |> preload([:user, :image])
      |> order_by(desc: :created_at)
      |> limit(25)
      |> Repo.all()

    render(conn, "show.html", image: conn.assigns.image, comments: comments)
  end
end
