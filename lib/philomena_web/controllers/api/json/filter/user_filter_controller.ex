defmodule PhilomenaWeb.Api.Json.Filter.UserFilterController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.FilterJson
  alias Philomena.Filters.Filter
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, _params) do
    user = conn.assigns.current_user
    page = conn.assigns.pagination.page_number
    page_size = conn.assigns.pagination.page_size

    case user do
      nil ->
        conn
        |> put_status(:forbidden)
        |> text("")

      _ ->
        user_filters =
          Filter
          |> where(user_id: ^user.id)
          |> order_by(asc: :id)
          |> preload(:user)
          |> limit(^page_size)
          |> offset((^page - 1) * ^page_size)
          |> Repo.all()

        json(conn, %{
          filters: Enum.map(user_filters, &FilterJson.as_json/1),
          page: page
        })
    end
  end
end
