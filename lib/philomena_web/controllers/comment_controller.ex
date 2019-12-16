defmodule PhilomenaWeb.CommentController do
  use PhilomenaWeb, :controller

  alias Philomena.{Comments.Query, Comments.Comment, Textile.Renderer}
  import Ecto.Query

  def index(conn, params) do
    cq = params["cq"] || "created_at.gte:1 week ago"

    params = Map.put(conn.params, "cq", cq)
    conn = Map.put(conn, :params, params)

    {:ok, query} = Query.compile(conn.assigns.current_user, cq)

    comments =
      Comment.search_records(
        %{
          query: %{
            bool: %{
              must: query,
              must_not: [
                %{terms: %{image_tag_ids: conn.assigns.current_filter.hidden_tag_ids}},
                %{term: %{hidden_from_users: true}}
              ]
            }
          },
          sort: %{posted_at: :desc}
        },
        conn.assigns.pagination,
        Comment |> preload([image: [:tags], user: [awards: :badge]])
      )

    rendered =
      comments.entries
      |> Renderer.render_collection(conn)

    comments =
      %{comments | entries: Enum.zip(rendered, comments.entries)}

    render(conn, "index.html", title: "Comments", comments: comments)
  end
end
