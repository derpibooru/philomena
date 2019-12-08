defmodule PhilomenaWeb.ImageController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageLoader
  alias PhilomenaWeb.NotificationCountPlug
  alias Philomena.{Images, Images.Image, Comments.Comment, Galleries.Gallery, Galleries.Interaction, Textile.Renderer}
  alias Philomena.Servers.ImageProcessor
  alias Philomena.UserStatistics
  alias Philomena.Interactions
  alias Philomena.Comments
  alias Philomena.Tags
  alias Philomena.Repo
  import Ecto.Query

  plug :load_image when action in [:show]

  plug PhilomenaWeb.FilterBannedUsersPlug when action in [:new, :create]
  plug PhilomenaWeb.UserAttributionPlug when action in [:create]
  plug PhilomenaWeb.CaptchaPlug when action in [:create]
  plug PhilomenaWeb.ScraperPlug, [params_name: "image", params_key: "image"] when action in [:create]
  plug PhilomenaWeb.AdvertPlug when action in [:show]

  def index(conn, _params) do
    {:ok, {images, _tags}} = ImageLoader.search_string(conn, "created_at.lte:3 minutes ago")

    interactions =
      Interactions.user_interactions(images, conn.assigns.current_user)

    render(conn, "index.html", layout_class: "layout--wide", images: images, interactions: interactions)
  end

  def show(conn, %{"id" => _id}) do
    image = conn.assigns.image
    user = conn.assigns.current_user

    Images.clear_notification(image, user)

    # Update the notification ticker in the header
    conn = NotificationCountPlug.call(conn)

    comments =
      Comment
      |> where(image_id: ^image.id)
      |> preload([:image, user: [awards: :badge]])
      |> order_by(desc: :created_at)
      |> limit(25)
      |> Repo.paginate(conn.assigns.comment_scrivener)

    rendered =
      comments.entries
      |> Renderer.render_collection(conn)

    comments =
      %{comments | entries: Enum.zip(comments.entries, rendered)}

    description =
      %{body: image.description}
      |> Renderer.render_one(conn)

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

    {user_galleries, image_galleries} = image_and_user_galleries(image, conn.assigns.current_user)

    assigns = [
      image: image,
      comments: comments,
      image_changeset: image_changeset,
      comment_changeset: comment_changeset,
      image_galleries: image_galleries,
      user_galleries: user_galleries,
      description: description,
      interactions: interactions,
      watching: watching,
      layout_class: "layout--wide"
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

    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"image" => image_params}) do
    attributes = conn.assigns.attributes

    case Images.create_image(attributes, image_params) do
      {:ok, %{image: image}} ->
        ImageProcessor.cast(image.id)
        Images.reindex_image(image)
        Tags.reindex_tags(image.added_tags)
        UserStatistics.inc_stat(conn.assigns.current_user, :uploads)

        conn
        |> put_flash(:info, "Image created successfully.")
        |> redirect(to: Routes.image_path(conn, :show, image))

      {:error, :image, changeset, _} ->
        conn
        |> render("new.html", changeset: changeset)
    end
  end

  defp image_and_user_galleries(_image, nil), do: {[], []}
  defp image_and_user_galleries(image, user) do
    image_galleries =
      Gallery
      |> where(creator_id: ^user.id)
      |> join(:inner, [g], gi in Interaction, on: g.id == gi.gallery_id and gi.image_id == ^image.id)
      |> Repo.all()

    image_gallery_ids = Enum.map(image_galleries, & &1.id)

    user_galleries =
      Gallery
      |> where(creator_id: ^user.id)
      |> where([g], g.id not in ^image_gallery_ids)
      |> Repo.all()

    {user_galleries, image_galleries}
  end

  defp load_image(conn, _opts) do
    id = conn.params["id"]

    {image, tag_changes, source_changes} =
      Image
      |> where(id: ^id)
      |> join(:inner_lateral, [i], _ in fragment("SELECT COUNT(*) FROM tag_changes t WHERE t.image_id = ?", i.id))
      |> join(:inner_lateral, [i, _], _ in fragment("SELECT COUNT(*) FROM source_changes s WHERE s.image_id = ?", i.id))
      |> preload([:tags, :deleter, user: [awards: :badge]])
      |> select([i, t, s], {i, t.count, s.count})
      |> Repo.one()

    cond do
      is_nil(image) ->
        PhilomenaWeb.NotFoundPlug.call(conn)

      not is_nil(image.duplicate_id) and not Canada.Can.can?(conn.assigns.current_user, :show, image) ->
        conn
        |> put_flash(:info, "The image you were looking for has been marked a duplicate of the image below")
        |> redirect(to: Routes.image_path(conn, :show, image.duplicate_id))

      true ->
        conn
        |> assign(:image, image)
        |> assign(:tag_change_count, tag_changes)
        |> assign(:source_change_count, source_changes)
    end
  end
end
