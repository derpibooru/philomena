defmodule PhilomenaWeb.Api.Json.Search.ImageController do
  use PhilomenaWeb, :controller

  alias Philomena.Images
  alias Philomena.Interactions

  def index(conn, _params) do
    scope = PhilomenaWeb.ImageScope.search_scope(conn)

    case Images.query_images(conn.assigns.actor, scope,
           preload: [:user, :intensity, :sources, tags: :aliases],
           hits: false
         ) do
      {:ok, %{images: images}} ->
        interactions = Interactions.user_interactions(conn.assigns.actor, images)

        conn
        |> put_view(PhilomenaWeb.Api.Json.ImageView)
        |> render("index.json",
          images: images,
          total: images.total_entries,
          interactions: interactions
        )

      {:error, msg} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})
    end
  end
end
