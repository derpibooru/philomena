defmodule PhilomenaWeb.Topic.ApproveController do
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
  plug PhilomenaWeb.CanaryMapPlug, create: :approve
  plug :authorize_resource, model: Topic, persisted: true

  def create(conn, _params) do
    topic = conn.assigns.topic
    user = conn.assigns.current_user

    case Topics.approve_topic(topic) do
      {:ok, topic} ->
        conn
        |> put_flash(:info, "Topic successfully approved!")
        |> moderation_log(details: &log_details/3, data: topic)
        |> redirect(to: Routes.forum_topic_path(conn, :show, topic.forum, topic))

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Unable to approve the topic!")
        |> redirect(to: Routes.forum_topic_path(conn, :show, topic.forum, topic))
    end
  end

  defp log_details(conn, action, topic) do
    %{
      body: "Approved topic '#{topic.title}' in #{topic.forum.name}",
      subject_path: Routes.forum_topic_path(conn, :show, topic.forum, topic)
    }
  end
end
