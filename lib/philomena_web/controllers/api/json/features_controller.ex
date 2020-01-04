defmodule PhilomenaWeb.Api.Json.FeatureController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageJson
  alias Philomena.ImageFeatures.ImageFeature
  alias Philomena.Images.Image
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, _params) do
    featured_image =
      Image
      |> join(:inner, [i], f in ImageFeature, on: [image_id: i.id])
      |> order_by([_i, f], desc: f.created_at)
      |> limit(1)
      |> preload([:tags, :user, :intensity])
      |> Repo.one()

    case featured_image do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("")

      _ ->
        json(conn, %{image: ImageJson.as_json(conn, featured_image)})
    end
  end
end
