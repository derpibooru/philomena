defmodule PhilomenaWeb.Image.SourceController do
  use PhilomenaWeb, :controller

  alias Philomena.SourceChanges.SourceChange
  alias Philomena.UserStatistics
  alias Philomena.Images.Image
  alias Philomena.Images.Source
  alias Philomena.Images
  alias Philomena.Repo
  import Ecto.Query

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
    preload: [:user, :sources, tags: :aliases]

  def update(conn, %{"image" => image_params}) do
    attributes = conn.assigns.attributes
    image = conn.assigns.image

    case Images.update_sources(image, attributes, image_params) do
      {:ok, %{image: {image, added_sources, removed_sources}}} ->
        PhilomenaWeb.Endpoint.broadcast!(
          "firehose",
          "image:source_update",
          %{image_id: image.id, added: [added_sources], removed: [removed_sources]}
        )

        PhilomenaWeb.Endpoint.broadcast!(
          "firehose",
          "image:update",
          PhilomenaWeb.Api.Json.ImageView.render("show.json", %{image: image, interactions: []})
        )

        changeset =
          %{image | sources: sources_for_edit(image.sources)}
          |> Images.change_image()

        source_change_count =
          SourceChange
          |> where(image_id: ^image.id)
          |> Repo.aggregate(:count, :id)

        if Enum.any?(added_sources) or Enum.any?(removed_sources) do
          UserStatistics.inc_stat(conn.assigns.current_user.id, :metadata_updates)
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

  # TODO: this is duplicated in ImageController
  defp sources_for_edit(), do: [%Source{}]
  defp sources_for_edit([]), do: sources_for_edit()
  defp sources_for_edit(sources), do: sources
end
