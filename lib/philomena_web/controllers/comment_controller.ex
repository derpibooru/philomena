defmodule PhilomenaWeb.CommentController do
  use PhilomenaWeb, :controller

  alias Philomena.{Images.Image, Comments.Comment, Textile.Renderer}
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, params) do
    comments =
      Comment.search_records(
        %{
          query: %{
            bool: %{
              must: parse_search(conn, params) ++ [%{term: %{hidden_from_users: false}}]
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

  defp parse_search(conn, %{"comment" => comment_params}) do
    parse_author(comment_params) ++
    parse_image_id(conn, comment_params) ++
    parse_body(comment_params)
  end
  defp parse_search(_conn, _params), do: [%{match_all: %{}}]

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

  defp parse_image_id(conn, %{"image_id" => image_id}) when image_id not in [nil, ""] do
    with {image_id, _rest} <- Integer.parse(image_id),
         true <- valid_image?(conn.assigns.current_user, image_id)
    do
      [%{term: %{image_id: image_id}}]
    else
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

  defp valid_image?(user, image_id) do
    image =
      Image
      |> where(id: ^image_id)
      |> Repo.one()

    Canada.Can.can?(user, :show, image)
  end
end
