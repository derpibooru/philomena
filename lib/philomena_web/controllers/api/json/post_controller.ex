defmodule PhilomenaWeb.Api.Json.PostController do
  use PhilomenaWeb, :controller

  alias Philomena.Posts
  import PhilomenaWeb.Api.Json.NotFound

  def show(conn, %{"id" => post_id}) do
    case Posts.show_post(conn.assigns.actor, post_id) do
      {:ok, post} ->
        conn
        |> put_view(PhilomenaWeb.Api.Json.Forum.Topic.PostView)
        |> render("show.json", post: post)

      {:error, reason} when reason in [:not_found, :unauthorized] ->
        not_found(conn)
    end
  end
end
