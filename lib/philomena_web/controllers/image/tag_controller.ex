defmodule PhilomenaWeb.Image.TagController do
  use PhilomenaWeb, :controller

  alias Philomena.TagChanges
  alias Philomena.UserStatistics
  alias Philomena.Comments
  alias Philomena.Images.Image
  alias Philomena.Images
  alias Philomena.Tags
  alias Philomena.Repo
  alias Plug.Conn

  plug PhilomenaWeb.LimitPlug,
       [time: 5, error: "You may only update metadata once every 5 seconds."]
       when action in [:update]

  plug PhilomenaWeb.FilterBannedUsersPlug
  plug PhilomenaWeb.CaptchaPlug
  plug PhilomenaWeb.CheckCaptchaPlug
  plug PhilomenaWeb.UserAttributionPlug
  plug PhilomenaWeb.CanaryMapPlug, update: :edit_metadata

  plug :load_and_authorize_resource,
    model: Image,
    id_name: "image_id",
    preload: [:user, :locked_tags, :sources, tags: :aliases]

  def update(conn, %{"image" => image_params}) do
    attributes = conn.assigns.attributes
    image = conn.assigns.image

    case Images.update_tags(image, attributes, image_params) do
      {:ok, %{image: {image, added_tags, removed_tags}}} ->
        PhilomenaWeb.Endpoint.broadcast!(
          "firehose",
          "image:tag_update",
          %{
            image_id: image.id,
            added: Enum.map(added_tags, & &1.name),
            removed: Enum.map(removed_tags, & &1.name)
          }
        )

        PhilomenaWeb.Endpoint.broadcast!(
          "firehose",
          "image:update",
          PhilomenaWeb.Api.Json.ImageView.render("show.json", %{image: image, interactions: []})
        )

        Comments.reindex_comments_on_image(image)
        Images.reindex_image(image)
        Tags.reindex_tags(added_tags ++ removed_tags)

        if Enum.any?(added_tags ++ removed_tags) do
          UserStatistics.inc_stat(conn.assigns.current_user, :metadata_updates)
        end

        tag_change_count = TagChanges.count_tag_changes(:image_id, image.id)

        image =
          image
          |> Repo.preload([:sources, tags: :aliases], force: true)

        changeset = Images.change_image(image)

        conn
        |> put_view(PhilomenaWeb.ImageView)
        |> render("_tags.html",
          layout: false,
          tag_change_count: tag_change_count,
          image: image,
          changeset: changeset
        )

      {:error, :image, changeset, _} ->
        image =
          image
          |> Repo.preload([:sources, tags: :aliases], force: true)

        conn
        |> put_view(PhilomenaWeb.ImageView)
        |> render("_tags.html",
          layout: false,
          tag_change_count: 0,
          image: image,
          changeset: changeset
        )

      {:error, :check_limits, _error, _} ->
        conn
        |> put_flash(:error, "Too many tags changed. Change fewer tags or try again later.")
        |> Conn.send_resp(:multiple_choices, "")
        |> Conn.halt()

      _err ->
        conn
        |> put_flash(:error, "Failed to update tags!")
        |> Conn.send_resp(:multiple_choices, "")
        |> Conn.halt()
    end
  end
end
