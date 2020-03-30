defmodule PhilomenaWeb.Api.Json.Filter.SystemFilterController do
  use PhilomenaWeb, :controller

  alias Philomena.Filters.Filter
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, _params) do
    system_filters =
      Filter
      |> where(system: true)
      |> order_by(asc: :id)
      |> Repo.paginate(conn.assigns.scrivener)

    conn
    |> put_view(PhilomenaWeb.Api.Json.FilterView)
    |> render("index.json", filters: system_filters, total: system_filters.total_entries)
  end
end
