defmodule PhilomenaWeb.GalleryController do
  use PhilomenaWeb, :controller

  alias Philomena.Galleries.Gallery
  import Ecto.Query

  plug :load_resource, model: Gallery, preload: [:creator, thumbnail: :tags]

  def index(conn, params) do
    galleries =
      Gallery.search_records(
        %{
          query: %{
            bool: %{
              must: parse_search(params)
            }
          },
          sort: parse_sort(params),
        },
        conn.assigns.pagination,
        Gallery |> preload([:creator, thumbnail: :tags])
      )

    render(conn, "index.html", galleries: galleries, layout_class: "layout--wide")
  end

  def show(_conn, _params) do
  end

  defp parse_search(%{"gallery" => gallery_params}) do
    parse_title(gallery_params) ++
    parse_creator(gallery_params) ++
    parse_included_image(gallery_params) ++
    parse_description(gallery_params)
  end
  defp parse_search(_params), do: [%{match_all: %{}}]

  defp parse_title(%{"title" => title}) when is_binary(title) and title not in [nil, ""],
    do: [%{wildcard: %{title: "*" <> String.downcase(title) <> "*"}}]
  defp parse_title(_params), do: []

  defp parse_creator(%{"creator" => creator}) when is_binary(creator) and creator not in [nil, ""],
    do: [%{term: %{creator: String.downcase(creator)}}]
  defp parse_creator(_params), do: []

  defp parse_included_image(%{"include_image" => image_id}) when is_binary(image_id) and image_id not in [nil, ""] do
    with {image_id, _rest} <- Integer.parse(image_id) do
      [%{term: %{image_id: image_id}}]
    else
      _ ->
        []
    end
  end
  defp parse_included_image(_params), do: []

  defp parse_description(%{"description" => description}) when is_binary(description) and description not in [nil, ""],
    do: [%{match: %{description: %{query: description, operator: :and}}}]
  defp parse_description(_params), do: []

  defp parse_sort(%{"gallery" => %{"sf" => sf, "sd" => sd}})
    when sf in ["created_at", "updated_at", "image_count", "_score"]
    and sd in ["desc", "asc"]
  do
    %{sf => sd}
  end
  defp parse_sort(_params) do
    %{created_at: :desc}
  end
end