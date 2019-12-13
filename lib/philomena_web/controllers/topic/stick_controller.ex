defmodule PhilomenaWeb.Topic.StickController do
  import Plug.Conn
  use PhilomenaWeb, :controller

  alias Philomena.Topics.Topic
  alias Philomena.Topics
  alias Philomena.Repo
  import Ecto.Query

  plug :load_topic
  plug PhilomenaWeb.CanaryMapPlug, create: :stick, delete: :stick
  plug :authorize_resource, model: Topic, id_name: "topic_id", persisted: true

  def create(conn, _opts) do
    topic = conn.assigns.topic

    case Topics.stick_topic(topic) do
      {:ok, topic} ->
        conn
        |> put_flash(:info, "Topic successfully stickied!")
        |> redirect(to: Routes.forum_topic_path(conn, :show, topic.forum_id, topic.id))
      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Unable to stick the topic!")
        |> redirect(to: Routes.forum_topic_path(conn, :show, topic.forum_id, topic.id))
    end
  end

  def delete(conn, _opts) do
    topic = conn.assigns.topic

    case Topics.unstick_topic(topic) do
      {:ok, topic} ->
        conn
        |> put_flash(:info, "Topic successfully unstickied!")
        |> redirect(to: Routes.forum_topic_path(conn, :show, topic.forum_id, topic.id))
      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Unable to unstick the topic!")
        |> redirect(to: Routes.forum_topic_path(conn, :show, topic.forum_id, topic.id))
    end
  end

  defp load_topic(conn, _opts) do
    topic = Topic
    |> where(forum_id: ^conn.params["forum_id"], slug: ^conn.params["topic_id"])
    |> Repo.one()

    Plug.Conn.assign(conn, :topic, topic)
  end
end
