defmodule PhilomenaWeb.Api.Json.Search.PostController do
  use PhilomenaWeb, :controller

  alias Philomena.Posts

  def index(conn, params) do
    case Posts.query_posts(
           conn.assigns.actor,
           params["q"],
           conn.assigns.pagination
         ) do
      {:ok, posts} ->
        conn
        |> put_view(PhilomenaWeb.Api.Json.Forum.Topic.PostView)
        |> render("index.json", posts: posts, total: posts.total_entries)

      {:error, msg} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})
    end
  end
end
