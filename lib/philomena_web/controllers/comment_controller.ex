defmodule PhilomenaWeb.CommentController do
  use PhilomenaWeb, :controller

  alias Philomena.{Comments.Comment, Textile.Renderer}
  import Ecto.Query

  def index(conn, params) do
    comments =
      Comment.search_records(
        %{
          query: %{
            bool: %{
              must: parse_search(params) ++ [%{term: %{hidden_from_users: false}}]
            }
          },
          sort: parse_sort(params)
        },
        conn.assigns.pagination,
        Comment |> preload([image: [:tags], user: [awards: :badge]])
      )

    rendered =
      comments.entries
      |> Renderer.render_collection()

    comments =
      %{comments | entries: Enum.zip(comments.entries, rendered)}

    render(conn, "index.html", comments: comments)
  end

  defp parse_search(%{"comment" => comment_params}) do
    parse_author(comment_params) ++
    parse_image_id(comment_params) ++
    parse_body(comment_params)
  end
  defp parse_search(_params), do: [%{match_all: %{}}]

  defp parse_author(%{"author" => author}) when author not in [nil, ""] do
    case String.contains?(author, ["*", "?"]) do
      true ->
        [
          %{wildcard: %{author: author}},
          %{term: %{anonymous: false}}
        ]

      false ->
        [
          %{term: %{author: author}},
          %{term: %{anonymous: false}}
        ]
    end
  end
  defp parse_author(_params), do: []

  defp parse_image_id(%{"image_id" => image_id}) when image_id not in [nil, ""] do
    case Integer.parse(image_id) do
      {image_id, _rest} ->
        [%{term: %{image_id: image_id}}]

      _error ->
        []
    end
  end
  defp parse_image_id(_params), do: []

  defp parse_body(%{"body" => body}) when body not in [nil, ""],
    do: [%{match: %{body: body}}]
  defp parse_body(_params), do: []

  defp parse_sort(%{"comment" => %{"sf" => sf, "sd" => sd}}) when sf in ["posted_at", "_score"] and sd in ["desc", "asc"] do
    %{sf => sd}
  end
  defp parse_sort(_params) do
    %{posted_at: :desc}
  end
end
