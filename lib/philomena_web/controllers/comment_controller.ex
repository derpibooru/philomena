defmodule PhilomenaWeb.CommentController do
  use PhilomenaWeb, :controller

  alias Philomena.{Comments.Query, Comments.Comment, Textile.Renderer}
  import Ecto.Query

  def index(conn, params) do
    cq = params["cq"] || "created_at.gte:1 week ago"

    params = Map.put(conn.params, "cq", cq)
    conn = Map.put(conn, :params, params)
    user = conn.assigns.current_user

    {:ok, query} = Query.compile(user, cq)

    comments =
      Comment.search_records(
        %{
          query: %{
            bool: %{
              must: [query | filters(user)],
              must_not: %{
                terms: %{image_tag_ids: conn.assigns.current_filter.hidden_tag_ids}
              }
            }
          },
          sort: %{posted_at: :desc}
        },
        conn.assigns.pagination,
        Comment |> preload([:deleted_by, image: [:tags], user: [awards: :badge]])
      )

    rendered =
      comments.entries
      |> Renderer.render_collection(conn)

    comments =
      %{comments | entries: Enum.zip(rendered, comments.entries)}

    render(conn, "index.html", title: "Comments", comments: comments)
  end

  defp filters(%{role: role}) when role in ["moderator", "admin"], do: []
  defp filters(_user),
    do: [%{term: %{hidden_from_users: false}}]
end
