defmodule PhilomenaWeb.PostController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.MarkdownRenderer
  alias Philomena.Elasticsearch
  alias Philomena.{Posts.Query, Posts.Post}
  import Ecto.Query

  def index(conn, params) do
    pq = params["pq"] || "created_at.gte:1 week ago"

    params = Map.put(conn.params, "pq", pq)
    conn = Map.put(conn, :params, params)
    user = conn.assigns.current_user

    user
    |> Query.compile(pq)
    |> render_index(conn, user)
  end

  defp render_index({:ok, query}, conn, user) do
    posts =
      Post
      |> Elasticsearch.search_definition(
        %{
          query: %{
            bool: %{
              must: [query | filters(user)]
            }
          },
          sort: %{created_at: :desc}
        },
        conn.assigns.pagination
      )
      |> Elasticsearch.search_records(
        preload(Post, [:deleted_by, topic: :forum, user: [awards: :badge]])
      )

    rendered = MarkdownRenderer.render_collection(posts.entries, conn)

    posts = %{posts | entries: Enum.zip(rendered, posts.entries)}

    render(conn, "index.html", title: "Posts", posts: posts)
  end

  defp render_index({:error, msg}, conn, _user) do
    render(conn, "index.html", title: "Posts", error: msg, posts: [])
  end

  defp filters(%{role: role}) when role in ["moderator", "admin"], do: []

  defp filters(%{role: "assistant"}) do
    [
      %{terms: %{access_level: ["normal", "assistant"]}}
    ]
  end

  defp filters(_user) do
    [
      %{term: %{access_level: "normal"}},
      %{term: %{deleted: false}}
    ]
  end
end
