defmodule PhilomenaWeb.Api.Json.Search.CommentController do
  use PhilomenaWeb, :controller

  alias Philomena.Comments

  def index(conn, params) do
    actor = conn.assigns.actor
    filter = conn.assigns.current_filter

    case Comments.query_comments(actor, filter, params["q"], conn.assigns.pagination) do
      {:ok, comments} ->
        conn
        |> put_view(PhilomenaWeb.Api.Json.CommentView)
        |> render("index.json", comments: comments, total: comments.total_entries)

      {:error, msg} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})
    end
  end
end
