defmodule PhilomenaWeb.ImageController do
  use PhilomenaWeb, :controller

  alias Philomena.{Images, Images.Image, Comments.Comment, Textile.Renderer}
  alias Philomena.Interactions
  alias Philomena.Comments
  alias Philomena.Repo
  import Ecto.Query

  plug :load_and_authorize_resource, model: Image, only: :show, preload: [:tags, user: [awards: :badge]]

  plug PhilomenaWeb.FilterBannedUsersPlug when action in [:new, :create]
  plug PhilomenaWeb.UserAttributionPlug when action in [:create]
  plug PhilomenaWeb.CaptchaPlug when action in [:create]

  def index(conn, _params) do
    query = conn.assigns.compiled_filter

    images =
      Image.search_records(
        %{
          query: %{bool: %{must_not: [query, %{term: %{hidden_from_users: true}}]}},
          sort: %{created_at: :desc}
        },
        conn.assigns.pagination,
        Image |> preload([:tags, :user])
      )

    interactions =
      Interactions.user_interactions(images, conn.assigns.current_user)

    render(conn, "index.html", layout_class: "layout--wide", images: images, interactions: interactions)
  end

  def show(conn, %{"id" => _id}) do
    image = conn.assigns.image

    comments =
      Comment
      |> where(image_id: ^image.id)
      |> preload([:image, user: [awards: :badge]])
      |> order_by(desc: :created_at)
      |> limit(25)
      |> Repo.paginate(conn.assigns.scrivener)

    rendered =
      comments.entries
      |> Renderer.render_collection()

    comments =
      %{comments | entries: Enum.zip(comments.entries, rendered)}

    description =
      %{body: image.description}
      |> Renderer.render_one()

    interactions =
      Interactions.user_interactions([image], conn.assigns.current_user)

    comment_changeset =
      %Comment{}
      |> Comments.change_comment()

    image_changeset =
      image
      |> Images.change_image()

    watching =
      Images.subscribed?(image, conn.assigns.current_user)

    render(
      conn,
      "show.html",
      image: image,
      comments: comments,
      image_changeset: image_changeset,
      comment_changeset: comment_changeset,
      description: description,
      interactions: interactions,
      watching: watching,
      layout_class: "layout--wide"
    )
  end

  def new(conn, _params) do
    changeset =
      %Image{}
      |> Images.change_image()

    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"image" => image_params}) do
    attributes = conn.assigns.attributes

    case Images.create_image(attributes, image_params) do
      {:ok, %{image: image}} ->
        Images.reindex_image(image)

        conn
        |> put_flash(:info, "Image created successfully.")
        |> redirect(to: Routes.image_path(conn, :show, image))

      {:error, :image, changeset, _} ->
        conn
        |> render("new.html", changeset: changeset)
    end
  end
end
