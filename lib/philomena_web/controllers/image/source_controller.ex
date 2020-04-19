defmodule PhilomenaWeb.Image.SourceController do
  use PhilomenaWeb, :controller

  alias Philomena.SourceChanges.SourceChange
  alias Philomena.UserStatistics
  alias Philomena.Images.Image
  alias Philomena.Images
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
    old_source = image.source_url

    case Images.update_source(image, attributes, image_params) do
      {:ok, %{image: image}} ->
        changeset = Images.change_image(image)

        source_change_count =
          SourceChange
          |> where(image_id: ^image.id)
          |> Repo.aggregate(:count, :id)

        if old_source != image.source_url do
          UserStatistics.inc_stat(conn.assigns.current_user, :metadata_updates)
        end

        Images.reindex_image(image)

        conn
        |> put_view(PhilomenaWeb.ImageView)
        |> render("_source.html",
          layout: false,
          source_change_count: source_change_count,
          image: image,
          changeset: changeset
        )

      {:error, :image, changeset, _} ->
        conn
        |> put_view(PhilomenaWeb.ImageView)
        |> render("_source.html",
          layout: false,
          source_change_count: 0,
          image: image,
          changeset: changeset
        )
    end
  end
end
