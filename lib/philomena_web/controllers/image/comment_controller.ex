defmodule PhilomenaWeb.Image.CommentController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.CommentLoader
  alias PhilomenaWeb.TextileRenderer
  alias Philomena.{Images.Image, Comments.Comment}
  alias Philomena.UserStatistics
  alias Philomena.Comments
  alias Philomena.Images

  plug PhilomenaWeb.LimitPlug,
       [time: 30, error: "You may only create a comment once every 30 seconds."]
       when action in [:create]

  plug PhilomenaWeb.FilterBannedUsersPlug when action in [:create, :edit, :update]
  plug PhilomenaWeb.UserAttributionPlug when action in [:create]

  plug PhilomenaWeb.CanaryMapPlug,
    create: :create_comment,
    edit: :create_comment,
    update: :create_comment

  plug :load_and_authorize_resource,
    model: Image,
    id_name: "image_id",
    persisted: true,
    preload: [tags: :aliases]

  plug :verify_authorized when action in [:show]
  plug PhilomenaWeb.FilterForcedUsersPlug when action in [:create, :edit, :update]

  # Undo the previous private parameter screwery
  plug PhilomenaWeb.LoadCommentPlug, [param: "id", show_hidden: true] when action in [:show]
  plug PhilomenaWeb.LoadCommentPlug, [param: "id"] when action in [:edit, :update]
  plug PhilomenaWeb.CanaryMapPlug, create: :create, edit: :edit, update: :edit

  plug :authorize_resource,
    model: Comment,
    only: [:edit, :update],
    preload: [:image, user: [awards: :badge]]

  def index(conn, %{"comment_id" => comment_id}) do
    page = CommentLoader.find_page(conn, conn.assigns.image, comment_id)

    redirect(conn, to: Routes.image_comment_path(conn, :index, conn.assigns.image, page: page))
  end

  def index(conn, _params) do
    comments = CommentLoader.load_comments(conn, conn.assigns.image)

    rendered = TextileRenderer.render_collection(comments.entries, conn)

    comments = %{comments | entries: Enum.zip(comments.entries, rendered)}

    render(conn, "index.html", layout: false, image: conn.assigns.image, comments: comments)
  end

  def show(conn, _params) do
    rendered = TextileRenderer.render_one(conn.assigns.comment, conn)

    render(conn, "show.html",
      layout: false,
      image: conn.assigns.image,
      comment: conn.assigns.comment,
      body: rendered
    )
  end

  def create(conn, %{"comment" => comment_params}) do
    attributes = conn.assigns.attributes
    image = conn.assigns.image

    case Comments.create_comment(image, attributes, comment_params) do
      {:ok, %{comment: comment}} ->
        PhilomenaWeb.Endpoint.broadcast!(
          "firehose",
          "comment:create",
          PhilomenaWeb.Api.Json.CommentView.render("show.json", %{comment: comment})
        )

        Comments.notify_comment(comment)
        Comments.reindex_comment(comment)
        Images.reindex_image(conn.assigns.image)
        UserStatistics.inc_stat(conn.assigns.current_user, :comments_posted)

        index(conn, %{"comment_id" => comment.id})

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

    render(conn, "edit.html",
      title: "Editing Comment",
      comment: conn.assigns.comment,
      changeset: changeset
    )
  end

  def update(conn, %{"comment" => comment_params}) do
    case Comments.update_comment(conn.assigns.comment, conn.assigns.current_user, comment_params) do
      {:ok, %{comment: comment}} ->
        PhilomenaWeb.Endpoint.broadcast!(
          "firehose",
          "comment:update",
          PhilomenaWeb.Api.Json.CommentView.render("show.json", %{comment: comment})
        )

        Comments.reindex_comment(comment)

        conn
        |> put_flash(:info, "Comment updated successfully.")
        |> redirect(
          to: Routes.image_path(conn, :show, conn.assigns.image) <> "#comment_#{comment.id}"
        )

      {:error, :comment, changeset, _changes} ->
        render(conn, "edit.html", comment: conn.assigns.comment, changeset: changeset)
    end
  end

  defp verify_authorized(conn, _params) do
    image = conn.assigns.image

    image =
      case is_nil(image.duplicate_id) do
        true -> image
        _false -> Images.get_image!(image.duplicate_id)
      end

    conn = assign(conn, :image, image)

    case Canada.Can.can?(conn.assigns.current_user, :show, image) do
      true -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
