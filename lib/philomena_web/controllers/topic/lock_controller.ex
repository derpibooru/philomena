defmodule PhilomenaWeb.Topic.LockController do
  import Plug.Conn
  use PhilomenaWeb, :controller

  alias Philomena.Topics.Topic
  alias Philomena.Topics
  alias Philomena.Repo
  import Ecto.Query

  plug :load_topic
  plug PhilomenaWeb.CanaryMapPlug, create: :lock, delete: :unlock
  plug :authorize_resource, model: Topic, id_name: "topic_id", persisted: true

  def create(conn, %{"topic" => topic_params}) do
    topic = conn.assigns.topic
    user = conn.assigns.current_user

    case Topics.lock_topic(topic, topic_params, user) do
      {:ok, topic} ->
        conn
        |> put_flash(:info, "Topic successfully locked!")
        |> redirect(to: Routes.forum_topic_path(conn, :show, topic.forum, topic))
      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Unable to lock the topic!")
        |> redirect(to: Routes.forum_topic_path(conn, :show, topic.forum, topic))
    end
  end

  def delete(conn, _opts) do
    topic = conn.assigns.topic

    case Topics.unlock_topic(topic) do
      {:ok, topic} ->
        conn
        |> put_flash(:info, "Topic successfully unlocked!")
        |> redirect(to: Routes.forum_topic_path(conn, :show, topic.forum, topic))
      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Unable to unlock the topic!")
        |> redirect(to: Routes.forum_topic_path(conn, :show, topic.forum, topic))
    end
  end

  defp load_topic(conn, _opts) do
    topic = Topic
    |> where(forum_id: ^conn.params["forum_id"], slug: ^conn.params["topic_id"])
    |> preload([:forum])
    |> Repo.one()

    Plug.Conn.assign(conn, :topic, topic)
  end
end
