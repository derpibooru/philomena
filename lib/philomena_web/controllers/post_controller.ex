defmodule PhilomenaWeb.PostController do
  use PhilomenaWeb, :controller

  alias Philomena.{Forums.Forum,  Posts.Post, Textile.Renderer}
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, params) do
    user = conn.assigns.current_user

    posts =
      Post.search_records(
        %{
          query: %{
            bool: %{
              must: parse_search(conn, params) ++ [%{term: %{deleted: false}}]
            }
          },
          sort: parse_sort(params)
        },
        conn.assigns.pagination,
        Post |> preload([topic: :forum, user: [awards: :badge]])
      )

    rendered =
      posts.entries
      |> Renderer.render_collection()

    posts =
      %{posts | entries: Enum.zip(posts.entries, rendered)}

    forums =
      Forum
      |> order_by(asc: :name)
      |> Repo.all()
      |> Enum.filter(&Canada.Can.can?(user, :show, &1))
      |> Enum.map(&{&1.name, &1.id})

    forums = [{"-", ""} | forums]

    render(conn, "index.html", posts: posts, forums: forums, layout_class: "layout--wide")
  end

  defp parse_search(conn, %{"post" => post_params}) do
    parse_author(post_params) ++
    parse_subject(post_params) ++
    parse_forum_id(conn, post_params) ++
    parse_body(post_params)
  end
  defp parse_search(_conn, _params), do: [%{match_all: %{}}]

  defp parse_author(%{"author" => author}) when is_binary(author) and author not in [nil, ""] do
    case String.contains?(author, ["*", "?"]) do
      true ->
        [
          %{wildcard: %{author: String.downcase(author)}},
          %{term: %{anonymous: false}}
        ]

      false ->
        [
          %{term: %{author: String.downcase(author)}},
          %{term: %{anonymous: false}}
        ]
    end
  end
  defp parse_author(_params), do: []

  defp parse_subject(%{"subject" => subject}) when is_binary(subject) and subject not in [nil, ""] do
    [%{match: %{subject: %{query: subject, operator: "and"}}}]
  end
  defp parse_subject(_params), do: []

  defp parse_forum_id(conn, %{"forum_id" => forum_id}) when is_binary(forum_id) and forum_id not in [nil, ""] do
    with {forum_id, _rest} <- Integer.parse(forum_id),
         true <- valid_forum?(conn.assigns.current_user, forum_id)
    do
        [%{term: %{forum_id: forum_id}}]
    else
      _error ->
        []
    end
  end
  defp parse_forum_id(_conn, _params), do: []

  defp parse_body(%{"body" => body}) when is_binary(body) and body not in [nil, ""],
    do: [%{match: %{body: body}}]
  defp parse_body(_params), do: []

  defp parse_sort(%{"post" => %{"sf" => sf, "sd" => sd}}) when sf in ["created_at", "_score"] and sd in ["desc", "asc"] do
    %{sf => sd}
  end
  defp parse_sort(_params) do
    %{created_at: :desc}
  end

  defp valid_forum?(user, forum_id) do
    forum =
      Forum
      |> where(id: ^forum_id)
      |> Repo.one()

    Canada.Can.can?(user, :show, forum)
  end
end