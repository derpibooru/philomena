defmodule PhilomenaWeb.Api.Json.Filter.UserFilterController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.FilterJson
  alias Philomena.Filters.Filter
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, _params) do
    user = conn.assigns.current_user

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
          |> Repo.paginate(conn.assigns.scrivener)

        json(conn, %{
          filters: Enum.map(user_filters, &FilterJson.as_json/1),
          total: user_filters.total_entries
        })
    end
  end
end
