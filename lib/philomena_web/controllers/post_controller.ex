defmodule PhilomenaWeb.PostController do
  use PhilomenaWeb, :controller

  alias Philomena.Posts
  alias PhilomenaWeb.MarkdownRenderer

  def index(conn, params) do
    pq = params["pq"] || "created_at.gte:1 week ago"

    params = Map.put(conn.params, "pq", pq)
    conn = Map.put(conn, :params, params)

    conn.assigns.actor
    |> Posts.query_posts(pq, conn.assigns.pagination)
    |> render_index(conn)
  end

  defp render_index({:ok, posts}, conn) do
    rendered = MarkdownRenderer.render_collection(posts.entries, conn)

    posts = %{posts | entries: Enum.zip(rendered, posts.entries)}

    render(conn, "index.html", title: "Posts", posts: posts)
  end

  defp render_index({:error, msg}, conn) do
    render(conn, "index.html", title: "Posts", error: msg, posts: [])
  end
end
