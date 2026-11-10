defmodule PhilomenaWeb.Api.Json.CommentController do
  use PhilomenaWeb, :controller

  alias Philomena.Comments
  import PhilomenaWeb.Api.Json.NotFound

  def show(conn, %{"id" => id}) do
    case Comments.show_comment(conn.assigns.actor, id) do
      {:ok, comment} ->
        render(conn, "show.json", comment: comment)

      {:error, :not_found} ->
        not_found(conn)

      {:error, :unauthorized} ->
        conn
        |> put_status(:forbidden)
        |> text("")
    end
  end
end
