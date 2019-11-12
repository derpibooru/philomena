defmodule PhilomenaWeb.Image.CommentController do
  use PhilomenaWeb, :controller

  alias Philomena.{Images.Image, Comments.Comment, Textile.Renderer}
  alias Philomena.Repo
  import Ecto.Query

  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true
  plug :load_and_authorize_resource, model: Comment, only: [:show], preload: [:image, :user]

  def index(conn, _params) do
    comments =
      Comment
      |> where(image_id: ^conn.assigns.image.id)
      |> order_by(desc: :created_at)
      |> preload([:image, :user])
      |> Repo.paginate(conn.assigns.scrivener)

    rendered =
      comments.entries
      |> Renderer.render_collection()

    comments =
      %{comments | entries: Enum.zip(comments.entries, rendered)}

    render(conn, "index.html", layout: false, image: conn.assigns.image, comments: comments)
  end

  def show(conn, _params) do
    rendered = Renderer.render_one(conn.assigns.comment)
    render(conn, "show.html", layout: false, image: conn.assigns.image, comment: conn.assigns.comment, body: rendered)
  end
end
