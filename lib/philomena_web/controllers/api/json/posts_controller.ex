defmodule PhilomenaWeb.Api.Json.PostsController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.PostJson
  alias Philomena.Topics.Topic
  alias Philomena.Posts.Post
  alias Philomena.Forums.Forum
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, %{"forums_id" => forum_id, "topics_id" => topic_id}) do
    posts = 
      Post
      |> where(topic_id: ^topic_id)
      |> where(destroyed_content: false)
      |> order_by(asc: :id)
      |> preload([:user, :topic])
      |> Repo.paginate(conn.assigns.scrivener)

    topic = 
      Topic
      |> where(forum_id: ^forum_id)
      |> where(id: ^topic_id)
      |> preload([:user, :forum])
      |> Repo.one()

    cond do
      is_nil(posts) ->
        conn
        |> put_status(:not_found)
        |> text("")

      topic.hidden_from_users ->
        conn
        |> put_status(:forbidden)
        |> text("")

      true ->
        json(conn, %{posts: Enum.map(posts, &PostJson.as_json/1)})

    end
  end


  def show(conn, %{"forums_id" => forum_id, "topics_id" => _topic_id, "id" => post_id}) do
    post = 
      Post
      |> where(id: ^post_id)
      |> preload([:user, :topic])
      |> Repo.one()
    forum =
      Forum
      |> where(id: ^forum_id)
      |> Repo.one()

    cond do
      is_nil(post) or post.destroyed_content ->
        conn
        |> put_status(:not_found)
        |> text("")

      post.topic.hidden_from_users or forum.access_level != "normal" ->
        conn
        |> put_status(:forbidden)
        |> text("")

      true ->
        json(conn, %{post: PostJson.as_json(post)})

    end
  end
end
