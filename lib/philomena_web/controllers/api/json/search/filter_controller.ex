defmodule PhilomenaWeb.Api.Json.Search.FilterController do
  use PhilomenaWeb, :controller

  alias PhilomenaQuery.Search
  alias Philomena.Filters.Filter
  alias Philomena.Filters.Query
  import Ecto.Query

  def index(conn, params) do
    user = conn.assigns.current_user

    case Query.compile(params["q"], user: user) do
      {:ok, query} ->
        filters =
          Filter
          |> Search.search_definition(
            %{
              query: %{
                bool: %{
                  must: [
                    query,
                    %{
                      bool: %{
                        should:
                          [%{term: %{public: true}}, %{term: %{system: true}}] ++
                            user_should(user)
                      }
                    }
                  ]
                }
              },
              sort: [
                %{name: :asc},
                %{id: :desc}
              ]
            },
            conn.assigns.pagination
          )
          |> Search.search_records(preload(Filter, [:user]))

        conn
        |> put_view(PhilomenaWeb.Api.Json.FilterView)
        |> render("index.json", filters: filters, total: filters.total_entries)

      {:error, msg} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})
    end
  end

  defp user_should(user) do
    case user do
      nil ->
        []

      user ->
        [%{term: %{user_id: user.id}}]
    end
  end
end
