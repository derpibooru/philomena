defmodule PhilomenaWeb.ImageController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageLoader
  alias PhilomenaWeb.CommentLoader
  alias PhilomenaWeb.NotificationCountPlug
  alias PhilomenaWeb.MarkdownRenderer

  alias Philomena.{
    Images,
    Images.Image,
    Images.Source,
    Comments.Comment,
    Galleries.Gallery
    }

  alias Philomena.Elasticsearch
  alias Philomena.Interactions
  alias Philomena.Comments
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.LimitPlug,
       [time: 5, error: "You may only upload images once every 5 seconds."]
       when action in [:create]

  plug :load_image when action in [:show]

  plug PhilomenaWeb.FilterBannedUsersPlug when action in [:new, :create]
  plug PhilomenaWeb.UserAttributionPlug when action in [:create]
  plug PhilomenaWeb.CaptchaPlug when action in [:new, :show, :create]
  plug PhilomenaWeb.CheckCaptchaPlug when action in [:create]

  plug PhilomenaWeb.ScraperPlug,
       [params_name: "image", params_key: "image"] when action in [:create]

  plug PhilomenaWeb.AdvertPlug when action in [:show]

  def index(conn, _params) do
    {:ok, {images, _tags}} =
      ImageLoader.search_string(conn, "created_at.lte:3 minutes ago, -thumbnails_generated:false")

    images = Elasticsearch.search_records(images, preload(Image, tags: :aliases))

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

    conn = maybe_skip_to_last_comment_page(conn, image, user)

    comments = CommentLoader.load_comments(conn, image)

    rendered = MarkdownRenderer.render_collection(comments.entries, conn)

    comments = %{comments | entries: Enum.zip(comments.entries, rendered)}

    description =
      %{body: image.description}
      |> MarkdownRenderer.render_one(conn)

    interactions = Interactions.user_interactions([image], conn.assigns.current_user)

    comment_changeset =
      %Comment{}
      |> Comments.change_comment()

    image_changeset =
      %{image | sources: sources_for_edit(image.sources)}
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
      title: "##{image.id} - #{Images.tag_list(image)}"
    ]

    if image.hidden_from_users do
      render(conn, "deleted.html", assigns)
    else
      render(conn, "show.html", assigns)
    end
  end

  def new(conn, _params) do
    changeset =
      %Image{sources: sources_for_edit()}
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

  defp maybe_skip_to_last_comment_page(conn, image, %{
         comments_newest_first: false,
         comments_always_jump_to_last: true
       }) do
    page = CommentLoader.last_page(conn, image)

    conn
    |> assign(:comment_scrivener, Keyword.merge(conn.assigns.comment_scrivener, page: page))
  end

  defp maybe_skip_to_last_comment_page(conn, _image, _user), do: conn

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
      ),
      on: true
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
        _ in fragment("SELECT COUNT(*) FROM tag_changes t WHERE t.image_id = ?", i.id),
        on: true
      )
      |> join(
        :inner_lateral,
        [i, _],
        _ in fragment("SELECT COUNT(*) FROM source_changes s WHERE s.image_id = ?", i.id),
        on: true
      )
      |> preload([:deleter, :locked_tags, :sources, user: [awards: :badge], tags: :aliases])
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

  defp sources_for_edit(), do: [%Source{}]
  defp sources_for_edit([]), do: sources_for_edit()
  defp sources_for_edit(sources), do: sources
end
