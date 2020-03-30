defmodule PhilomenaWeb.Api.Json.Forum.Topic.PostController do
  use PhilomenaWeb, :controller

  alias Philomena.Posts.Post
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, %{"forum_id" => forum_id, "topic_id" => topic_id}) do
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
      |> preload([:user, :topic])
      |> preload([_p, t, _f], topic: t)
      |> Repo.all()

    render(conn, "index.json", posts: posts, total: hd(posts).topic.post_count)
  end

  def show(conn, %{"forum_id" => forum_id, "topic_id" => topic_id, "id" => post_id}) do
    post =
      Post
      |> join(:inner, [p], _ in assoc(p, :topic))
      |> join(:inner, [_p, t], _ in assoc(t, :forum))
      |> where(id: ^post_id)
      |> where(destroyed_content: false)
      |> where([_p, t], t.hidden_from_users == false and t.slug == ^topic_id)
      |> where([_p, _t, f], f.access_level == "normal" and f.short_name == ^forum_id)
      |> preload([:user, :topic])
      |> Repo.one()

    cond do
      is_nil(post) ->
        conn
        |> put_status(:not_found)
        |> text("")

      true ->
        render(conn, "show.json", post: post)
    end
  end
end
