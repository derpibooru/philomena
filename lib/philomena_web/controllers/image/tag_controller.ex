defmodule PhilomenaWeb.Image.TagController do
  use PhilomenaWeb, :controller

  alias Philomena.UserStatistics
  alias Philomena.Images.Image
  alias Philomena.Images
  alias Philomena.Tags
  alias Philomena.Repo

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
        Images.reindex_image(image)
        Tags.reindex_tags(added_tags ++ removed_tags)
        UserStatistics.inc_stat(conn.assigns.current_user, :metadata_updates)

        image =
          image
          |> Repo.preload(:tags, force: true)

        changeset =
          Images.change_image(image)

        conn
        |> put_view(PhilomenaWeb.ImageView)
        |> render("_tags.html", layout: false, image: image, changeset: changeset)

      {:error, :image, changeset, _} ->
        conn
        |> put_view(PhilomenaWeb.ImageView)
        |> render("_tags.html", layout: false, image: image, changeset: changeset)
    end
  end
end