defmodule PhilomenaWeb.Api.Json.Search.ReverseController do
  use PhilomenaWeb, :controller

  alias Philomena.DuplicateReports
  alias Philomena.DuplicateReports.SearchResult
  alias Philomena.Interactions

  plug PhilomenaWeb.ScraperCachePlug
  plug PhilomenaWeb.ScraperPlug, params_key: "image", params_name: "image"

  def create(conn, %{"image" => image_params}) do
    upload = PhilomenaMedia.Upload.cast(image_params, "image")

    {images, total} =
      image_params
      |> Map.put("distance", conn.params["distance"])
      |> Map.put("limit", conn.params["limit"])
      |> then(&DuplicateReports.create_reverse_search(conn.assigns.actor, &1, upload))
      |> case do
        {:ok, %SearchResult{images: images}} ->
          {images, images.total_entries}

        {:error, _changeset} ->
          {[], 0}
      end

    interactions = Interactions.user_interactions(conn.assigns.actor, images)

    conn
    |> put_view(PhilomenaWeb.Api.Json.ImageView)
    |> render("index.json",
      images: images,
      total: total,
      interactions: interactions
    )
  end
end
