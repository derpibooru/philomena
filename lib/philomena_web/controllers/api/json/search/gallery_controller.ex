defmodule PhilomenaWeb.Api.Json.Search.GalleryController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.GalleryJson
  alias Philomena.Elasticsearch
  alias Philomena.Galleries.Gallery
  alias Philomena.Galleries.Query
  import Ecto.Query

  def index(conn, params) do
    case Query.compile(params["q"] || "") do
      {:ok, query} ->
        galleries =
          Elasticsearch.search_records(
            Gallery,
            %{
              query: query,
              sort: %{created_at: :desc}
            },
            conn.assigns.pagination,
            preload(Gallery, [:creator])
          )

        json(conn, %{galleries: Enum.map(galleries, &GalleryJson.as_json/1)})

      {:error, msg} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})
    end
  end
end
