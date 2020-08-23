defmodule PhilomenaWeb.Image.RandomController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageSorter
  alias PhilomenaWeb.ImageScope
  alias Philomena.Elasticsearch
  alias Philomena.Images.Query
  alias Philomena.Images.Image

  def index(conn, params) do
    user = conn.assigns.current_user
    filter = conn.assigns.compiled_filter

    scope = ImageScope.scope(conn)
    query = query(user, params)
    random_id = random_image_id(query, filter)

    if random_id do
      redirect(conn, to: Routes.image_path(conn, :show, random_id, scope))
    else
      redirect(conn, external: conn.assigns.referrer)
    end
  end

  defp query(user, %{"q" => q}) do
    {:ok, query} = Query.compile(user, q)

    query
  end

  defp query(_user, _), do: %{match_all: %{}}

  defp random_image_id(query, filter) do
    %{query: query, sorts: sort} = ImageSorter.parse_sort(%{"sf" => "random"}, query)

    Image
    |> Elasticsearch.search_definition(
      %{
        query: %{
          bool: %{
            must: query,
            must_not: [
              filter,
              %{term: %{hidden_from_users: true}}
            ]
          }
        },
        sort: sort
      },
      %{page_size: 1}
    )
    |> Elasticsearch.search_records(Image)
    |> Enum.to_list()
    |> unwrap()
  end

  defp unwrap([image]), do: image.id
  defp unwrap([]), do: nil
end
