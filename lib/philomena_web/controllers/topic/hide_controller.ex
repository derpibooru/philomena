defmodule PhilomenaWeb.Topic.HideController do
  import Plug.Conn
  use PhilomenaWeb, :controller

  alias Philomena.Topics.Topic
  alias Philomena.Topics
  alias Philomena.Repo
  import Ecto.Query

  plug :load_topic
  plug PhilomenaWeb.CanaryMapPlug, create: :hide, delete: :hide
  plug :authorize_resource, model: Topic, id_name: "topic_id", persisted: true

  def create(conn, %{"topic" => topic_params}) do
    topic = conn.assigns.topic
    deletion_reason = topic_params["deletion_reason"]
    user = conn.assigns.current_user

    case Topics.hide_topic(topic, deletion_reason, user) do
      {:ok, topic} ->
        conn
        |> put_flash(:info, "Topic successfully hidden!")
        |> redirect(to: Routes.forum_topic_path(conn, :show, topic.forum, topic))
      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Unable to hide the topic!")
        |> redirect(to: Routes.forum_topic_path(conn, :show, topic.forum, topic))
    end
  end

  def delete(conn, _opts) do
    topic = conn.assigns.topic

    case Topics.unhide_topic(topic) do
      {:ok, topic} ->
        conn
        |> put_flash(:info, "Topic successfully restored!")
        |> redirect(to: Routes.forum_topic_path(conn, :show, topic.forum, topic))
      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Unable to restore the topic!")
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
