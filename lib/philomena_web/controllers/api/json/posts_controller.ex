defmodule PhilomenaWeb.Api.Json.PostController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.PostJson
  alias Philomena.Posts.Post
  alias Philomena.Repo
  import Ecto.Query

  def show(conn, %{"forum_id" => forum_id, "topic_id" => topic_id, "id" => post_id}) do
    post = 
      Post
      |> join(:inner, [p], _ in assoc(p, :topic))
      |> join(:inner, [_p, t], _ in assoc(t, :forum))
      |> where(id: ^post_id)
      |> where(destroyed_content: false)
      |> where([_p, t], t.hidden_from_users == false and t.slug == ^topic_id)
      |> where([_p, _t, f], f.access_level == "normal" and f.short_name == ^forum_id)      
      |> preload([:user])
      |> Repo.one()

    cond do
      is_nil(post) ->
        conn
        |> put_status(:not_found)
        |> text("")

      true ->
        json(conn, %{post: PostJson.as_json(post)})
    end
  end

  def index(conn, %{"forum_id" => forum_id, "topic_id" => topic_id} = params) do
    page = conn.assigns.pagination.page_number
    posts = 
      Post
      |> join(:inner, [p], _ in assoc(p, :topic))
      |> join(:inner, [_p, t], _ in assoc(t, :forum))
      |> where(destroyed_content: false)
      |> where([_p, t], t.hidden_from_users == false and t.slug == ^topic_id)
      |> where([_p, _t, f], f.access_level == "normal" and f.short_name == ^forum_id)
      |> where([p], p.topic_position >= ^(25 * (page - 1)) and p.topic_position < ^(25 * page))
      |> order_by(asc: :topic_position)
      |> preload([:user])
      |> Repo.all()

    json(conn, %{posts: Enum.map(posts, &PostJson.as_json/1), page: page})
  end
end
