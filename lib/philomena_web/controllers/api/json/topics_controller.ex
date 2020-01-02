defmodule PhilomenaWeb.Api.Json.TopicController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.TopicJson
  alias Philomena.Topics.Topic
  alias Philomena.Repo
  import Ecto.Query

  def show(conn, %{"forum_id" => forum_id, "id" => id}) do

    topic = 
      Topic
      |> where(slug: ^id)
      |> where(hidden_from_users: false)
      |> join(:inner, [t], _ in assoc(t, :forum))
      |> where([_t, f], f.access_level == "normal")
      |> where([_t, f], f.short_name == ^forum_id)
      |> order_by(desc: :sticky, desc: :last_replied_to_at)
      |> preload([:poll, :forum, :user, last_post: :user])
      |> preload([:user, :forum])
      |> Repo.one()

    cond do
      is_nil(topic) ->
        conn
        |> put_status(:not_found)
        |> text("")

      true ->
        json(conn, %{topic: TopicJson.as_json(topic)})
    end
  end

  def index(conn, %{"forum_id" => id}) do

    topics =
      Topic
      |> where(hidden_from_users: false)
      |> join(:inner, [t], _ in assoc(t, :forum))
      |> where([_t, f], f.access_level == "normal")
      |> where([_t, f], f.short_name == ^id)
      |> order_by(desc: :sticky, desc: :last_replied_to_at)
      |> preload([:poll, :forum, :user, last_post: :user])
      |> Repo.paginate(conn.assigns.scrivener)

    json(conn, %{topic: Enum.map(topics, &TopicJson.as_json/1)})
  end
end
