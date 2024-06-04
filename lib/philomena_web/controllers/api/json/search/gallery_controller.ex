defmodule PhilomenaWeb.Api.Json.Search.GalleryController do
  use PhilomenaWeb, :controller

  alias PhilomenaQuery.Search
  alias Philomena.Galleries.Gallery
  alias Philomena.Galleries.Query
  import Ecto.Query

  def index(conn, params) do
    case Query.compile(params["q"] || "") do
      {:ok, query} ->
        galleries =
          Gallery
          |> Search.search_definition(
            %{
              query: query,
              sort: %{created_at: :desc}
            },
            conn.assigns.pagination
          )
          |> Search.search_records(preload(Gallery, [:creator]))

        conn
        |> put_view(PhilomenaWeb.Api.Json.GalleryView)
        |> render("index.json", galleries: galleries, total: galleries.total_entries)

      {:error, msg} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})
    end
  end
end
