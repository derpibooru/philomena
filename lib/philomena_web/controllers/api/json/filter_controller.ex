defmodule PhilomenaWeb.Api.Json.FilterController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.FilterJson
  alias Philomena.Filters.Filter
  alias Philomena.Repo
  import Ecto.Query

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    filter =
      Filter
      |> where(id: ^id)
      |> preload(:user)
      |> Repo.one()

    case Canada.Can.can?(user, :show, filter) do
      true ->
        json(conn, %{filter: FilterJson.as_json(filter)})

      _ ->
        conn
        |> put_status(:not_found)
        |> text("")
    end
  end

  def index(conn, _params) do
    user = conn.assigns.current_user
    page = conn.assigns.pagination.page_number
    page_size = conn.assigns.pagination.page_size

    system_filters =
      Filter
      |> where(system: true)
      |> Repo.all()

    case user do
      nil ->
        json(conn, %{system_filters: Enum.map(system_filters, &FilterJson.as_json/1)})

      _ ->
        user_filters =
          Filter
          |> where(user_id: ^user.id)
          |> order_by(asc: :id)
          |> preload(:user)
          |> limit(^page_size)
          |> offset((^page - 1) * ^page_size)
          |> Repo.all()

        case page do
          1 ->
            json(conn, %{
              system_filters: Enum.map(system_filters, &FilterJson.as_json/1),
              user_filters: Enum.map(user_filters, &FilterJson.as_json/1),
              page: page
            })

          _ ->
            json(conn, %{
              user_filters: Enum.map(user_filters, &FilterJson.as_json/1),
              page: page
            })
        end
    end
  end
end
