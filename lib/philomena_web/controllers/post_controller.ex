defmodule PhilomenaWeb.PostController do
  use PhilomenaWeb, :controller

  alias Philomena.{Posts.Query, Posts.Post, Textile.Renderer}
  import Ecto.Query

  def index(conn, params) do
    pq = params["pq"] || "created_at.gte:1 week ago"

    params = Map.put(conn.params, "pq", pq)
    conn = Map.put(conn, :params, params)
    user = conn.assigns.current_user

    {:ok, query} = Query.compile(user, pq)

    posts =
      Post.search_records(
        %{
          query: %{
            bool: %{
              must: [query | filters(user)]
            }
          },
          sort: %{created_at: :desc}
        },
        conn.assigns.pagination,
        Post |> preload([:deleted_by, topic: :forum, user: [awards: :badge]])
      )

    rendered =
      posts.entries
      |> Renderer.render_collection(conn)

    posts =
      %{posts | entries: Enum.zip(rendered, posts.entries)}

    render(conn, "index.html", title: "Posts", posts: posts)
  end

  defp filters(%{role: role}) when role in ["moderator", "admin"], do: []

  defp filters(%{role: "assistant"}) do
    [
      %{terms: %{access_level: ["normal", "assistant"]}},
      %{term: %{deleted: false}}
    ]
  end

  defp filters(_user) do
    [
      %{term: %{access_level: "normal"}},
      %{term: %{deleted: false}}
    ]
  end
end
