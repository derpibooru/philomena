defmodule PhilomenaWeb.Api.Json.Search.FilterController do
  use PhilomenaWeb, :controller

  alias Philomena.Filters

  def index(conn, params) do
    case Filters.query_filters(conn.assigns.actor, params["q"], conn.assigns.pagination) do
      {:ok, filters} ->
        conn
        |> put_view(PhilomenaWeb.Api.Json.FilterView)
        |> render("index.json", filters: filters, total: filters.total_entries)

      {:error, msg} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})
    end
  end
end
