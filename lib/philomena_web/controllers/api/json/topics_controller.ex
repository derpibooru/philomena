defmodule PhilomenaWeb.Api.Json.TopicsController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.TopicJson
  alias Philomena.Topics.Topic
  alias Philomena.Forums.Forum
  alias Philomena.Repo
  import Ecto.Query

  def show(conn, %{"forums_id" => forum_id, "id" => id}) do
    topic = 
      Topic
      |> where(forum_id: ^forum_id)
      |> where(id: ^id)
      |> preload([:user, :forum])
      |> Repo.one()

    cond do
      is_nil(topic) ->
        conn
        |> put_status(:not_found)
        |> text("")

      topic.hidden_from_users or topic.forum.access_level != "normal" ->
        conn
        |> put_status(:forbidden)
        |> text("")

      true ->
        json(conn, %{topic: TopicJson.as_json(topic)})

    end
  end

  def index(conn, %{"forums_id" => id}) do
    forum = 
      Forum
      |> where(id: ^id)
      |> Repo.one()
    cond do
      forum.access_level != "normal" ->
        conn
        |> put_status(:forbidden)
        |> text("")
      true ->
        topics =
          Topic
          |> where(forum_id: ^id)
          |> where(hidden_from_users: false)
          |> order_by(desc: :sticky, desc: :last_replied_to_at)
          |> preload([:poll, :forum, :user, last_post: :user])
          |> Repo.paginate(conn.assigns.scrivener)
        json(conn, %{topic: Enum.map(topics, &TopicJson.as_json/1)})
    end
  end
end
