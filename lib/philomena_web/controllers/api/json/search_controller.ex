defmodule PhilomenaWeb.Api.Json.SearchController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageLoader
  alias PhilomenaWeb.ImageJson
  alias Philomena.ImageSorter
  alias Philomena.Interactions
  alias Philomena.Images.Image
  import Ecto.Query

  def index(conn, params) do
    queryable = Image |> preload([:tags, :user])
    user = conn.assigns.current_user
    sort = ImageSorter.parse_sort(params)

    case ImageLoader.search_string(conn, params["q"], sorts: sort.sorts, queries: sort.queries, queryable: queryable) do
      {:ok, {images, _tags}} ->
        interactions =
          Interactions.user_interactions(images, user)

        conn
        |> json(%{
          images: Enum.map(images, &ImageJson.as_json(conn, &1)),
          total: images.total_entries,
          interactions: interactions
        })

      {:error, msg} ->
        conn
        |> Plug.Conn.put_status(:bad_request)
        |> json(%{error: msg})
    end
  end
end