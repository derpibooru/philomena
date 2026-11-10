defmodule PhilomenaWeb.Api.Json.Image.FeaturedController do
  use PhilomenaWeb, :controller

  alias Philomena.Images
  alias Philomena.Interactions
  import PhilomenaWeb.Api.Json.NotFound

  def show(conn, _params) do
    case Images.show_featured_image(conn.assigns.actor, false) do
      {:ok, image} ->
        interactions = Interactions.user_interactions(conn.assigns.actor, [image])

        conn
        |> put_view(PhilomenaWeb.Api.Json.ImageView)
        |> render("show.json", image: image, interactions: interactions)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
