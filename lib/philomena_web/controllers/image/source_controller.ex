defmodule PhilomenaWeb.Image.SourceController do
  use PhilomenaWeb, :controller

  alias Philomena.UserStatistics
  alias Philomena.Images.Image
  alias Philomena.Images

  plug PhilomenaWeb.FilterBannedUsersPlug
  plug PhilomenaWeb.CaptchaPlug
  plug PhilomenaWeb.UserAttributionPlug
  plug PhilomenaWeb.CanaryMapPlug, update: :edit_metadata
  plug :load_and_authorize_resource, model: Image, id_name: "image_id"

  def update(conn, %{"image" => image_params}) do
    attributes = conn.assigns.attributes
    image = conn.assigns.image

    case Images.update_source(image, attributes, image_params) do
      {:ok, %{image: image}} ->
        changeset =
          Images.change_image(image)

        UserStatistics.inc_stat(conn.assigns.current_user, :metadata_updates)

        conn
        |> put_view(PhilomenaWeb.ImageView)
        |> render("_source.html", layout: false, image: image, changeset: changeset)

      {:error, :image, changeset, _} ->
        conn
        |> put_view(PhilomenaWeb.ImageView)
        |> render("_source.html", layout: false, image: image, changeset: changeset)
    end
  end
end