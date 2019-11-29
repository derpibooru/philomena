defmodule PhilomenaWeb.Topic.ReadController do
  import Plug.Conn
  use PhilomenaWeb, :controller

  alias Philomena.Forums.Forum
  alias Philomena.Topics.Topic
  alias Philomena.Topics
  alias Philomena.Repo
  import Ecto.Query

  plug :load_and_authorize_resource, model: Forum, id_name: "forum_id", id_field: "short_name", persisted: true

  def create(conn, %{"topic_id" => slug}) do
    topic = load_topic(conn, slug)
    user = conn.assigns.current_user

    Topics.clear_notification(topic, user)

    send_resp(conn, :ok, "")
  end

  defp load_topic(conn, slug) do
    forum = conn.assigns.forum

    Topic
    |> where(forum_id: ^forum.id, slug: ^slug, hidden_from_users: false)
    |> preload(:user)
    |> Repo.one()
  end
end