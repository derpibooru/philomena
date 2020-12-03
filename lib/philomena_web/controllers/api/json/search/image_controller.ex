defmodule PhilomenaWeb.Api.Json.Search.ImageController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageLoader
  alias Philomena.Elasticsearch
  alias Philomena.Interactions
  alias Philomena.Images.Image
  import Ecto.Query

  def index(conn, params) do
    queryable = Image |> preload([:user, :intensity, tags: :aliases])
    user = conn.assigns.current_user

    case ImageLoader.search_string(conn, params["q"]) do
      {:ok, {images, _tags}} ->
        images = Elasticsearch.search_records(images, queryable)
        interactions = Interactions.user_interactions(images, user)

        conn
        |> put_view(PhilomenaWeb.Api.Json.ImageView)
        |> render("index.json",
          images: images,
          total: images.total_entries,
          interactions: interactions
        )

      {:error, msg} ->
        conn
        |> Plug.Conn.put_status(:bad_request)
        |> json(%{error: msg})
    end
  end
end
