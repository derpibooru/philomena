defmodule PhilomenaWeb.ImageNavigator do
  alias PhilomenaWeb.ImageSorter
  alias Philomena.Images.Image
  alias PhilomenaQuery.Search

  @order_for_dir %{
    "next" => %{"asc" => "asc", "desc" => "desc"},
    "prev" => %{"asc" => "desc", "desc" => "asc"}
  }

  def find_consecutive(conn, image, compiled_query, compiled_filter) do
    conn = update_in(conn.params, &Map.put_new(&1, "sf", "first_seen_at"))

    %{query: compiled_query, sorts: sorts} = ImageSorter.parse_sort(conn.params, compiled_query)

    sorts =
      sorts
      |> Enum.flat_map(&Enum.to_list/1)
      |> Enum.map(&apply_direction(&1, conn.params["rel"]))

    search_after =
      conn.params["sort"]
      |> permit_list()
      |> Enum.flat_map(&permit_value/1)
      |> default_cursors(conn.params["sf"], image)

    maybe_search_after(
      Image,
      %{
        query: %{
          bool: %{
            must: compiled_query,
            must_not: [
              compiled_filter,
              %{term: %{hidden_from_users: true}},
              %{term: %{id: image.id}},
              hidden_filter(conn.assigns.current_user, conn.params["hidden"])
            ]
          }
        },
        sort: sorts,
        search_after: search_after
      },
      %{page_size: 1},
      Image,
      length(sorts) == length(search_after)
    )
    |> Enum.to_list()
    |> case do
      [] -> nil
      [next_image] -> next_image
    end
  end

  defp maybe_search_after(module, body, options, queryable, true) do
    module
    |> Search.search_definition(body, options)
    |> Search.search_records_with_hits(queryable)
  end

  defp maybe_search_after(_module, _body, _options, _queryable, _false) do
    []
  end

  defp default_cursors([], "id", image), do: [image.id]

  defp default_cursors([], "first_seen_at", image),
    do: [image.first_seen_at |> DateTime.to_unix(:millisecond), image.id]

  defp default_cursors(list, _sf, _image), do: list

  defp apply_direction({"galleries.position", sort_body}, rel) do
    sort_body = update_in(sort_body.order, fn direction -> @order_for_dir[rel][direction] end)

    %{"galleries.position" => sort_body}
  end

  defp apply_direction({field, direction}, rel) do
    %{field => @order_for_dir[rel][direction]}
  end

  defp permit_list(value) when is_list(value), do: value
  defp permit_list(_value), do: []

  defp permit_value(value) when is_binary(value) or is_number(value), do: [value]
  defp permit_value(_value), do: []

  defp hidden_filter(%{id: id}, param) when param != "1", do: %{term: %{hidden_by_user_ids: id}}
  defp hidden_filter(_user, _param), do: %{match_none: %{}}
end
