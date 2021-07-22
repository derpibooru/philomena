defmodule PhilomenaWeb.Api.Json.Image.FeaturedController do
  use PhilomenaWeb, :controller

  alias Philomena.ImageFeatures.ImageFeature
  alias Philomena.Images.Image
  alias Philomena.Interactions
  alias Philomena.Repo
  import Ecto.Query

  def show(conn, _params) do
    user = conn.assigns.current_user

    featured_image =
      Image
      |> join(:inner, [i], f in ImageFeature, on: [image_id: i.id])
      |> where([i], i.hidden_from_users == false)
      |> order_by([_i, f], desc: f.created_at)
      |> limit(1)
      |> preload([:user, :intensity, tags: :aliases])
      |> Repo.one()

    case featured_image do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("")
        |> halt()

      _ ->
        interactions = Interactions.user_interactions([featured_image], user)

        conn
        |> put_view(PhilomenaWeb.Api.Json.ImageView)
        |> render("show.json", image: featured_image, interactions: interactions)
    end
  end
end
