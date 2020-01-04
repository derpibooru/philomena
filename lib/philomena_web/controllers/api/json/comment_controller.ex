defmodule PhilomenaWeb.Api.Json.CommentController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.CommentJson
  alias Philomena.Comments.Comment
  alias Philomena.Repo
  import Ecto.Query

  def show(conn, %{"image_id" => image_id, "id" => id}) do
    comment = 
      Comment
      |> preload([:image, :user])
      |> join(:inner, [c], _ in assoc(c, :image))
      |> where(id: ^id)
      |> where(destroyed_content: false)
      |> where([_c, i], i.hidden_from_users == false and i.id == ^image_id)
      |> Repo.one()

    cond do
      is_nil(comment) or comment.destroyed_content ->
        conn
        |> put_status(:not_found)
        |> text("")

      true ->
        json(conn, %{comment: CommentJson.as_json(comment)})
    end
  end
  def show(conn, %{"id" => id}) do
    comment = 
      Comment
      |> join(:inner, [c], _ in assoc(c, :image))
      |> where(id: ^id)
      |> where(destroyed_content: false)
      |> where([_c, i], i.hidden_from_users == false)
      |> preload([:image, :user])
      |> Repo.one()

    cond do
      is_nil(comment) ->
        conn
        |> put_status(:not_found)
        |> text("")

      true ->
        json(conn, %{comment: CommentJson.as_json(comment)})
    end
  end

  def index(conn, %{"image_id" => image_id}) do
    page = conn.assigns.pagination.page_number
    comments = 
      Comment
      |> preload([:image, :user])
      |> join(:inner, [c], _ in assoc(c, :image))
      |> where(destroyed_content: false)
      |> where([_c, i], i.hidden_from_users == false and i.id == ^image_id)
      |> Repo.all()

    case comments do
      [] ->
        conn
        |> put_status(:not_found)
        |> text("")

      _ ->
        json(conn, %{comments: Enum.map(comments, &CommentJson.as_json/1), page: page, total: hd(comments).image.comments_count})
    end
  end
end
