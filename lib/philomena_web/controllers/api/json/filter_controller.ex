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

  defp check_permissions(nil, _user) do
    # Filter doesn't exist.
    nil
  end

  defp check_permissions(%{system: true} = filter, _user) do
    # Allow all system filters.
    filter
  end

  defp check_permissions(%{public: true} = filter, _user) do
    # Allow all public filters.
    filter
  end

  defp check_permissions(_filter, nil) do
    # I don't know why this would ever happen. Seemed prudent to add.
    nil
  end

  defp check_permissions(%{user: nil}, _user) do
    # Blocks non system/public filters that don't have a user assigned.
    nil
  end

  defp check_permissions(filter, user) do
    # Checks to see if the filter belongs to the user.
    if filter.user.id != user.id do
      nil
    else
      filter
    end
  end
end
