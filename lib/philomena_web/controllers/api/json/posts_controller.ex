defmodule PhilomenaWeb.Api.Json.PostController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.PostJson
  alias Philomena.Topics.Topic
  alias Philomena.Posts.Post
  alias Philomena.Forums.Forum
  alias Philomena.Repo
  import Ecto.Query

  def show(conn, %{"forum_id" => forum_id, "topic_id" => topic_id, "id" => post_id}) do

    forum =
      Forum
      |> where(short_name: ^forum_id)
      |> where(destroyed_content: false)
      |> Repo.one()

    topic = 
      Topic
      |> where(forum_id: ^forum.id)
      |> where(slug: ^topic_id)
      |> where(hidden_from_users: false)
      |> preload([:user, :forum])
      |> Repo.one()

    post = 
      Post
      |> where(id: ^post_id)
      |> where(topic_id: ^topic.id)
      |> where(destroyed_content: false)
      |> preload([:user, :topic])
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

    page = paginate(params["page"])
    forum =
      Forum
      |> where(short_name: ^forum_id)
      |> where(access_level: "normal")
      |> Repo.one()

    topic = 
      Topic
      |> where(forum_id: ^forum.id)
      |> where(slug: ^topic_id)
      |> where(hidden_from_users: false)
      |> preload([:user, :forum])
      |> Repo.one()

    posts = 
      Post
      |> where(topic_id: ^topic.id)
      |> where(destroyed_content: false)
      |> where([p], p.topic_position >= ^(25 * (page - 1)) and p.topic_position < ^(25 * page))
      |> order_by(asc: :topic_position)
      |> preload([:user, :topic])
      |> Repo.all()

    cond do
      is_nil(posts) ->
        conn
        |> put_status(:not_found)
        |> text("")

      true ->
        json(conn, %{posts: Enum.map(posts, &PostJson.as_json/1), page: page})
    end
  end

  defp paginate(page) do

    cond do
      is_nil(page) ->
        1

      String.to_integer(page) > 0 ->
        String.to_integer(page)

      true ->
        1

    end
  end
end
