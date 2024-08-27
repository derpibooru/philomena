defmodule PhilomenaWeb.Api.Json.Search.ReverseController do
  use PhilomenaWeb, :controller

  alias Philomena.DuplicateReports
  alias Philomena.Interactions

  plug PhilomenaWeb.ScraperCachePlug
  plug PhilomenaWeb.ScraperPlug, params_key: "image", params_name: "image"

  def create(conn, %{"image" => image_params}) do
    user = conn.assigns.current_user

    images =
      image_params
      |> Map.put("distance", conn.params["distance"])
      |> Map.put("limit", conn.params["limit"])
      |> DuplicateReports.execute_search_query()
      |> case do
        {:ok, images} ->
          images

        {:error, _changeset} ->
          []
      end

    interactions = Interactions.user_interactions(images, user)

    conn
    |> put_view(PhilomenaWeb.Api.Json.ImageView)
    |> render("index.json",
      images: images,
      total: images.total_entries,
      interactions: interactions
    )
  end
end
