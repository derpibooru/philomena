defmodule PhilomenaWeb.ImageController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageLoader
  alias PhilomenaWeb.CommentLoader
  alias PhilomenaWeb.NotificationCountPlug
  alias PhilomenaWeb.TextileRenderer

  alias Philomena.{
    Images,
    Images.Image,
    Comments.Comment,
    Galleries.Gallery
  }

  alias Philomena.Interactions
  alias Philomena.Comments
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.LimitPlug,
       [time: 10, error: "You may only upload images once every 10 seconds."]
       when action in [:create]


  plug :load_image when action in [:show]

  plug PhilomenaWeb.FilterBannedUsersPlug when action in [:new, :create]
  plug PhilomenaWeb.UserAttributionPlug when action in [:create]
  plug PhilomenaWeb.CaptchaPlug when action in [:create]

  plug PhilomenaWeb.ScraperPlug,
       [params_name: "image", params_key: "image"] when action in [:create]

  plug PhilomenaWeb.AdvertPlug when action in [:show]

  def index(conn, _params) do
    {:ok, {images, _tags}} = ImageLoader.search_string(conn, "created_at.lte:3 minutes ago")

    interactions = Interactions.user_interactions(images, conn.assigns.current_user)

    render(conn, "index.html",
      title: "Images",
      layout_class: "layout--wide",
      images: images,
      interactions: interactions
    )
  end

  def show(conn, %{"id" => _id}) do
    image = conn.assigns.image
    user = conn.assigns.current_user

    Images.clear_notification(image, user)

    # Update the notification ticker in the header
    conn = NotificationCountPlug.call(conn)

    comments = CommentLoader.load_comments(conn, image)

    rendered = TextileRenderer.render_collection(comments.entries, conn)

    comments = %{comments | entries: Enum.zip(comments.entries, rendered)}

    description =
      %{body: image.description}
      |> TextileRenderer.render_one(conn)

    interactions = Interactions.user_interactions([image], conn.assigns.current_user)

    comment_changeset =
      %Comment{}
      |> Comments.change_comment()

    image_changeset =
      image
      |> Images.change_image()

    watching = Images.subscribed?(image, conn.assigns.current_user)

    user_galleries = user_galleries(image, conn.assigns.current_user)

    assigns = [
      image: image,
      comments: comments,
      image_changeset: image_changeset,
      comment_changeset: comment_changeset,
      user_galleries: user_galleries,
      description: description,
      interactions: interactions,
      watching: watching,
      layout_class: "layout--wide",
      title: "##{image.id} - #{image.tag_list_cache}"
    ]

    if image.hidden_from_users do
      render(conn, "deleted.html", assigns)
    else
      render(conn, "show.html", assigns)
    end
  end

  def new(conn, _params) do
    changeset =
      %Image{}
      |> Images.change_image()

    render(conn, "new.html", title: "New Image", changeset: changeset)
  end

  def create(conn, %{"image" => image_params}) do
    attributes = conn.assigns.attributes

    case Images.create_image(attributes, image_params) do
      {:ok, %{image: image}} ->
        PhilomenaWeb.Endpoint.broadcast!(
          "firehose",
          "image:create",
          PhilomenaWeb.Api.Json.ImageView.render("show.json", %{image: image, interactions: []})
        )

        conn
        |> put_flash(:info, "Image created successfully.")
        |> redirect(to: Routes.image_path(conn, :show, image))

      {:error, :image, changeset, _} ->
        conn
        |> render("new.html", changeset: changeset)
    end
  end

  defp user_galleries(_image, nil), do: []

  defp user_galleries(image, user) do
    Gallery
    |> where(creator_id: ^user.id)
    |> join(
      :inner_lateral,
      [g],
      _ in fragment(
        "SELECT EXISTS(SELECT 1 FROM gallery_interactions gi WHERE gi.image_id = ? AND gi.gallery_id = ?)",
        ^image.id,
        g.id
      )
    )
    |> select([g, e], {g, e.exists})
    |> order_by(desc: :updated_at)
    |> Repo.all()
  end

  defp load_image(conn, _opts) do
    id = conn.params["id"]

    {image, tag_changes, source_changes} =
      Image
      |> where(id: ^id)
      |> join(
        :inner_lateral,
        [i],
        _ in fragment("SELECT COUNT(*) FROM tag_changes t WHERE t.image_id = ?", i.id)
      )
      |> join(
        :inner_lateral,
        [i, _],
        _ in fragment("SELECT COUNT(*) FROM source_changes s WHERE s.image_id = ?", i.id)
      )
      |> preload([:tags, :deleter, user: [awards: :badge]])
      |> select([i, t, s], {i, t.count, s.count})
      |> Repo.one()
      |> case do
        nil ->
          {nil, nil, nil}

        result ->
          result
      end

    cond do
      is_nil(image) ->
        PhilomenaWeb.NotFoundPlug.call(conn)

      not is_nil(image.duplicate_id) and
          not Canada.Can.can?(conn.assigns.current_user, :show, image) ->
        conn
        |> put_flash(
          :info,
          "The image you were looking for has been marked a duplicate of the image below"
        )
        |> redirect(to: Routes.image_path(conn, :show, image.duplicate_id))
        |> halt()

      true ->
        conn
        |> assign(:image, image)
        |> assign(:tag_change_count, tag_changes)
        |> assign(:source_change_count, source_changes)
    end
  end
end
