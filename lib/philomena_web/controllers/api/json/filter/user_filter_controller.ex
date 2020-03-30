defmodule PhilomenaWeb.Api.Json.Filter.UserFilterController do
  use PhilomenaWeb, :controller

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

        conn
        |> put_view(PhilomenaWeb.Api.Json.FilterView)
        |> render("index.json", filters: user_filters, total: user_filters.total_entries)
    end
  end
end
