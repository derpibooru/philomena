defmodule PhilomenaWeb.Topic.MoveController do
  import Plug.Conn
  use PhilomenaWeb, :controller

  alias Philomena.Forums.Forum
  alias Philomena.Topics.Topic
  alias Philomena.Topics
  alias Philomena.Repo

  plug PhilomenaWeb.CanaryMapPlug, create: :show, delete: :show

  plug :load_and_authorize_resource,
    model: Forum,
    id_name: "forum_id",
    id_field: "short_name",
    persisted: true

  plug PhilomenaWeb.LoadTopicPlug
  plug PhilomenaWeb.CanaryMapPlug, create: :hide, delete: :hide
  plug :authorize_resource, model: Topic, persisted: true

  def create(conn, %{"topic" => %{"target_forum_id" => target_id}}) do
    topic = conn.assigns.topic
    target_forum_id = String.to_integer(target_id)

    case Topics.move_topic(topic, target_forum_id) do
      {:ok, %{topic: topic}} ->
        topic = Repo.preload(topic, :forum, force: true)

        conn
        |> put_flash(:info, "Topic successfully moved!")
        |> redirect(to: Routes.forum_topic_path(conn, :show, topic.forum, topic))

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Unable to move the topic!")
        |> redirect(to: Routes.forum_topic_path(conn, :show, conn.assigns.forum, topic))
    end
  end
end
