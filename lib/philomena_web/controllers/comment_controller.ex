defmodule PhilomenaWeb.CommentController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.TextRenderer
  alias Philomena.Elasticsearch
  alias Philomena.{Comments.Query, Comments.Comment}
  import Ecto.Query

  def index(conn, params) do
    cq = params["cq"] || "created_at.gte:1 week ago"

    params = Map.put(conn.params, "cq", cq)
    conn = Map.put(conn, :params, params)
    user = conn.assigns.current_user

    user
    |> Query.compile(cq)
    |> render_index(conn, user)
  end

  defp render_index({:ok, query}, conn, user) do
    comments =
      Comment
      |> Elasticsearch.search_definition(
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
        conn.assigns.pagination
      )
      |> Elasticsearch.search_records(
        preload(Comment, [:deleted_by, image: [tags: :aliases], user: [awards: :badge]])
      )

    rendered = TextRenderer.render_collection(comments.entries, conn)

    comments = %{comments | entries: Enum.zip(rendered, comments.entries)}

    render(conn, "index.html", title: "Comments", comments: comments)
  end

  defp render_index({:error, msg}, conn, _user) do
    render(conn, "index.html", title: "Comments", error: msg, comments: [])
  end

  defp filters(%{role: role}) when role in ["assistant", "moderator", "admin"], do: []

  defp filters(_user),
    do: [%{term: %{hidden_from_users: false}}]
end
