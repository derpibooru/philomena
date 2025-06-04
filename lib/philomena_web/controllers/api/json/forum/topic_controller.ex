defmodule PhilomenaWeb.Api.Json.Forum.TopicController do
  use PhilomenaWeb, :controller

  alias Philomena.Topics.Topic
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, %{"forum_id" => id}) do
    topics =
      Topic
      |> join(:inner, [t], _ in assoc(t, :forum))
      |> where(hidden_from_users: false)
      |> where([_t, f], f.access_level == "normal" and f.short_name == ^id)
      |> order_by(desc: :sticky, desc: :last_replied_to_at)
      |> preload([:user])
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, "index.json", topics: topics, total: topics.total_entries)
  end

  def show(conn, %{"forum_id" => forum_id, "id" => id}) do
    topic =
      Topic
      |> join(:inner, [t], _ in assoc(t, :forum))
      |> where(slug: ^id)
      |> where(hidden_from_users: false)
      |> where([_t, f], f.access_level == "normal" and f.short_name == ^forum_id)
      |> order_by(desc: :sticky, desc: :last_replied_to_at)
      |> preload([:user])
      |> Repo.one()

    if is_nil(topic) do
      conn
      |> put_status(:not_found)
      |> text("")
    else
      render(conn, "show.json", topic: topic)
    end
  end
end
