defmodule PhilomenaWeb.PostController do
  use PhilomenaWeb, :controller

  alias Philomena.{Posts.Query, Posts.Post, Textile.Renderer}
  import Ecto.Query

  def index(conn, params) do
    pq = params["pq"] || "created_at.gte:1 week ago"

    params = Map.put(conn.params, "pq", pq)
    conn = Map.put(conn, :params, params)

    {:ok, query} = Query.compile(conn.assigns.current_user, pq)

    posts =
      Post.search_records(
        %{
          query: %{
            bool: %{
              must: [
                query,
                %{term: %{access_level: "normal"}},
              ],
              must_not: [
                %{term: %{hidden_from_users: true}}
              ]
            }
          },
          sort: %{created_at: :desc}
        },
        conn.assigns.pagination,
        Post |> preload([topic: :forum, user: [awards: :badge]])
      )

    rendered =
      posts.entries
      |> Renderer.render_collection(conn)

    posts =
      %{posts | entries: Enum.zip(rendered, posts.entries)}

    render(conn, "index.html", title: "Posts", posts: posts)
  end
end
