defmodule PhilomenaWeb.Topic.StickController do
  import Plug.Conn
  use PhilomenaWeb, :controller

  alias Philomena.Forums.Forum
  alias Philomena.Topics.Topic
  alias Philomena.Topics

  plug PhilomenaWeb.CanaryMapPlug, create: :show

  plug :load_and_authorize_resource,
    model: Forum,
    id_name: "forum_id",
    id_field: "short_name",
    persisted: true

  plug PhilomenaWeb.LoadTopicPlug
  plug PhilomenaWeb.CanaryMapPlug, create: :hide, delete: :hide
  plug :authorize_resource, model: Topic, persisted: true

  def create(conn, _opts) do
    topic = conn.assigns.topic

    case Topics.stick_topic(topic) do
      {:ok, topic} ->
        conn
        |> put_flash(:info, "Topic successfully stickied!")
        |> redirect(to: Routes.forum_topic_path(conn, :show, topic.forum, topic))

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Unable to stick the topic!")
        |> redirect(to: Routes.forum_topic_path(conn, :show, topic.forum, topic))
    end
  end

  def delete(conn, _opts) do
    topic = conn.assigns.topic

    case Topics.unstick_topic(topic) do
      {:ok, topic} ->
        conn
        |> put_flash(:info, "Topic successfully unstickied!")
        |> redirect(to: Routes.forum_topic_path(conn, :show, topic.forum, topic))

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Unable to unstick the topic!")
        |> redirect(to: Routes.forum_topic_path(conn, :show, topic.forum, topic))
    end
  end
end
