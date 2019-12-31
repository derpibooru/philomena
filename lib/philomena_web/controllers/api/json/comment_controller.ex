defmodule PhilomenaWeb.Api.Json.CommentController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.CommentJson
  alias Philomena.Comments.Comment
  alias Philomena.Repo
  import Ecto.Query

  def show(conn, %{"id" => id}) do
    comment = 
      Comment
      |> where(id: ^id)
      |> preload([:image, :user])
      |> Repo.one()

    cond do
      is_nil(comment) ->
        conn
        |> put_status(:not_found)
        |> text("")

      comment.image.hidden_from_users ->
        conn
        |> put_status(:forbidden)
        |> text("")

      true ->
        json(conn, %{comment: CommentJson.as_json(comment)})
        
    end
  end
end
