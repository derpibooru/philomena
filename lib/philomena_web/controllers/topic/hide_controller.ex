defmodule PhilomenaWeb.Topic.HideController do
  import Plug.Conn
  use PhilomenaWeb, :controller

  alias Philomena.Forums.Forum
  alias Philomena.Topics.Topic
  alias Philomena.Topics

  plug PhilomenaWeb.CanaryMapPlug, create: :show, delete: :show
  plug :load_and_authorize_resource, model: Forum, id_name: "forum_id", id_field: "short_name", persisted: true

  plug PhilomenaWeb.LoadTopicPlug
  plug PhilomenaWeb.CanaryMapPlug, create: :hide, delete: :hide
  plug :authorize_resource, model: Topic, persisted: true

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
end
