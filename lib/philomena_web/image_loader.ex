defmodule PhilomenaWeb.ImageLoader do
  alias Philomena.Images.{Image, Query}
  import Ecto.Query

  def search_string(conn, search_string, options \\ []) do
    user = conn.assigns.current_user

    with {:ok, tree} <- Query.compile(user, search_string) do
      {:ok, query(conn, tree, options)}
    else
      error ->
        error
    end
  end

  def query(conn, body, options \\ []) do
    sort_queries = Keyword.get(options, :queries, [])
    sort_sorts   = Keyword.get(options, :sorts, [%{created_at: :desc}])
    pagination   = Keyword.get(options, :pagination, conn.assigns.image_pagination)

    user    = conn.assigns.current_user
    filter  = conn.assigns.compiled_filter
    filters = create_filters(user, filter)

    Image.search_records(
      %{
        query: %{
          bool: %{
            must: List.flatten([body, sort_queries]),
            must_not: filters
          }
        },
        sort: sort_sorts
      },
      pagination,
      Image |> preload(:tags)
    )
  end

  defp create_filters(user, filter) do
    [
      filter,
      %{term: %{hidden_from_users: true}}
    ]
    |> maybe_custom_hide(user)
  end

  defp maybe_custom_hide(filters, %{id: id}),
    do: [%{term: %{hidden_by_user_ids: id}} | filters]

  defp maybe_custom_hide(filters, _user),
    do: filters
end