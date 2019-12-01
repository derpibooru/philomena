defmodule PhilomenaWeb.PostController do
  use PhilomenaWeb, :controller

  alias Philomena.{Posts.Query, Posts.Post, Textile.Renderer}
  import Ecto.Query

  def index(conn, params) do
    cq = params["pq"] || "created_at.gte:1 week ago"

    {:ok, query} = Query.compile(conn.assigns.current_user, cq)

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
                %{terms: %{image_tag_ids: conn.assigns.current_filter.hidden_tag_ids}},
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
      |> Renderer.render_collection()

    posts =
      %{posts | entries: Enum.zip(rendered, posts.entries)}

    render(conn, "index.html", posts: posts)
  end
end
