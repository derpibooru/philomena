defmodule PhilomenaWeb.Image.CommentController do
  use PhilomenaWeb, :controller

  alias Philomena.{Images.Image, Comments.Comment, Textile.Renderer}
  alias Philomena.Comments
  alias Philomena.Images
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.CanaryMapPlug, create: :create_comment, edit: :create_comment, update: :create_comment
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  # Undo the previous private parameter screwery
  plug PhilomenaWeb.CanaryMapPlug, create: :create, edit: :edit, update: :update
  plug :load_and_authorize_resource, model: Comment, only: [:show], preload: [:image, user: [awards: :badge]]

  plug PhilomenaWeb.FilterBannedUsersPlug when action in [:create, :edit, :update]
  plug PhilomenaWeb.UserAttributionPlug when action in [:create]

  def index(conn, %{"comment_id" => comment_id}) do
    comment =
      Comment
      |> where(image_id: ^conn.assigns.image.id)
      |> where(id: ^comment_id)
      |> Repo.one!()

    offset =
      Comment
      |> where(image_id: ^conn.assigns.image.id)
      |> where([c], c.created_at > ^comment.created_at)
      |> Repo.aggregate(:count, :id)

    %{page_size: page_size} = conn.assigns.pagination
    page = div(offset, page_size)

    conn
    |> redirect(to: Routes.image_comment_path(conn, :index, conn.assigns.image, page: page))
  end

  def index(conn, _params) do
    comments =
      Comment
      |> where(image_id: ^conn.assigns.image.id)
      |> order_by(desc: :created_at)
      |> preload([:image, user: [awards: :badge]])
      |> Repo.paginate(conn.assigns.comment_scrivener)

    rendered =
      comments.entries
      |> Renderer.render_collection(conn)

    comments =
      %{comments | entries: Enum.zip(comments.entries, rendered)}

    render(conn, "index.html", layout: false, image: conn.assigns.image, comments: comments)
  end

  def show(conn, _params) do
    rendered = Renderer.render_one(conn.assigns.comment, conn)
    render(conn, "show.html", layout: false, image: conn.assigns.image, comment: conn.assigns.comment, body: rendered)
  end

  def create(conn, %{"comment" => comment_params}) do
    attributes = conn.assigns.attributes
    image = conn.assigns.image

    case Comments.create_comment(image, attributes, comment_params) do
      {:ok, %{comment: comment}} ->
        Comments.notify_comment(comment)
        Comments.reindex_comment(comment)
        Images.reindex_image(conn.assigns.image)

        conn
        |> put_flash(:info, "Comment created successfully.")
        |> redirect(to: Routes.image_path(conn, :show, image) <> "#comment_#{comment.id}")

      _error ->
        conn
        |> put_flash(:error, "There was an error posting your comment")
        |> redirect(to: Routes.image_path(conn, :show, image))
    end
  end

  def edit(conn, _params) do
    changeset =
      conn.assigns.comment
      |> Comments.change_comment()

    render(conn, "edit.html", comment: conn.assigns.comment, changeset: changeset)
  end

  def update(conn, %{"comment" => comment_params}) do
    case Comments.update_comment(conn.assigns.comment, comment_params) do
      {:ok, _comment} ->
        conn
        |> put_flash(:info, "Comment updated successfully.")
        |> redirect(to: Routes.image_path(conn, :show, conn.assigns.image) <> "#comment_#{conn.assigns.comment.id}")

      _error ->
        conn
        |> put_flash(:error, "There was an error editing your comment")
        |> redirect(to: Routes.image_path(conn, :show, conn.assigns.image))
    end
  end
end
