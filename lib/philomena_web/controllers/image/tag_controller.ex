defmodule PhilomenaWeb.Image.TagController do
  use PhilomenaWeb, :controller

  alias Philomena.TagChanges.TagChange
  alias Philomena.UserStatistics
  alias Philomena.Comments
  alias Philomena.Images.Image
  alias Philomena.Images
  alias Philomena.Tags
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.FilterBannedUsersPlug
  plug PhilomenaWeb.CaptchaPlug
  plug PhilomenaWeb.UserAttributionPlug
  plug PhilomenaWeb.CanaryMapPlug, update: :edit_metadata
  plug :load_and_authorize_resource, model: Image, id_name: "image_id"

  def update(conn, %{"image" => image_params}) do
    attributes = conn.assigns.attributes
    image = conn.assigns.image

    case Images.update_tags(image, attributes, image_params) do
      {:ok, %{image: {image, added_tags, removed_tags}}} ->
        Comments.reindex_comments(image)
        Images.reindex_image(image)
        Tags.reindex_tags(added_tags ++ removed_tags)

        if Enum.any?(added_tags ++ removed_tags) do
          UserStatistics.inc_stat(conn.assigns.current_user, :metadata_updates)
        end

        tag_change_count =
          TagChange
          |> where(image_id: ^image.id)
          |> Repo.aggregate(:count, :id)

        image =
          image
          |> Repo.preload(:tags, force: true)

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
        conn
        |> put_view(PhilomenaWeb.ImageView)
        |> render("_tags.html",
          layout: false,
          tag_change_count: 0,
          image: image,
          changeset: changeset
        )
    end
  end
end
