defmodule PhilomenaWeb.Topic.MoveController do
  import Plug.Conn
  use PhilomenaWeb, :controller

  alias Philomena.Topics.Topic
  alias Philomena.Topics
  alias Philomena.Repo
  import Ecto.Query

  plug :load_topic
  plug PhilomenaWeb.CanaryMapPlug, create: :move
  plug :authorize_resource, model: Topic, id_name: "topic_id", persisted: true

  # intentionally blank
  # todo: moving
  def create(conn, %{"topic" => topic_params}) do
    topic = conn.assigns.topic

    case Topics.move_topic(topic, topic_params) do
      {:ok, topic} ->
        conn
        |> put_flash(:info, "Topic successfully moved!")
        |> redirect(to: Routes.forum_topic_path(conn, :show, topic_params["target_forum_id"] |> String.to_integer(), topic.id))
      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Unable to move the topic!")
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
