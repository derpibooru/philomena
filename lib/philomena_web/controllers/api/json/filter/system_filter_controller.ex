defmodule PhilomenaWeb.Api.Json.Filter.SystemFilterController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.FilterJson
  alias Philomena.Filters.Filter
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, _params) do
    page = conn.assigns.pagination.page_number
    page_size = conn.assigns.pagination.page_size

    system_filters =
      Filter
      |> where(system: true)
      |> order_by(asc: :id)
      |> limit(^page_size)
      |> offset((^page - 1) * ^page_size)
      |> Repo.all()

    json(conn, %{
      filters: Enum.map(system_filters, &FilterJson.as_json/1),
      page: page
    })
  end
end
