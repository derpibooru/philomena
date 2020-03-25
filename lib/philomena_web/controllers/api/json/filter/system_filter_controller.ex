defmodule PhilomenaWeb.Api.Json.Filter.SystemFilterController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.FilterJson
  alias Philomena.Filters.Filter
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, _params) do
    system_filters =
      Filter
      |> where(system: true)
      |> order_by(asc: :id)
      |> Repo.paginate(conn.assigns.scrivener)

    json(conn, %{
      filters: Enum.map(system_filters, &FilterJson.as_json/1),
      total: system_filters.total_entries
    })
  end
end
