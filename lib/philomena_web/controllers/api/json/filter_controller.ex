defmodule PhilomenaWeb.Api.Json.FilterController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.FilterJson
  alias Philomena.Filters.Filter
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.RecodeParameterPlug, [name: "id"] when action in [:show]

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    filter =
      Filter
      |> where(id: ^id)
      |> preload(:user)
      |> Repo.one()
      |> check_permissions(user)

    case filter do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("")

      _ ->
        json(conn, %{filter: FilterJson.as_json(filter)})
    end
  end

  defp check_permissions(filter, user) do
    case Canada.Can.can?(user, :show, filter) do
      true ->
        filter

      _ -> 
        nil
    end
  end
end
