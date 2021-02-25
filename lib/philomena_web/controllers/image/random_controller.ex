defmodule PhilomenaWeb.Image.RandomController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageSorter
  alias PhilomenaWeb.ImageScope
  alias PhilomenaWeb.ImageLoader
  alias Philomena.Elasticsearch
  alias Philomena.Images.Image

  def index(conn, params) do
    scope = ImageScope.scope(conn)

    search_definition =
      ImageLoader.search_string(
        conn,
        query_string(params),
        pagination: %{page_size: 1},
        sorts: &ImageSorter.parse_sort(%{"sf" => "random"}, &1)
      )

    case unwrap_random_result(search_definition) do
      nil ->
        redirect(conn, to: Routes.image_path(conn, :index))

      random_id ->
        redirect(conn, to: Routes.image_path(conn, :show, random_id, scope))
    end
  end

  defp query_string(%{"q" => query}), do: query
  defp query_string(_params), do: "*"

  defp unwrap_random_result({:ok, {definition, _tags}}) do
    definition
    |> Elasticsearch.search_records(Image)
    |> Enum.to_list()
    |> unwrap()
  end

  defp unwrap_random_result(_definition), do: nil

  defp unwrap([image]), do: image.id
  defp unwrap([]), do: nil
end
