defmodule PhilomenaWeb.Topic.StickController do
  import Plug.Conn
  use PhilomenaWeb, :controller

  alias Philomena.Forums.Forum
  alias Philomena.Topics.Topic
  alias Philomena.Topics

  plug PhilomenaWeb.CanaryMapPlug, create: :show, delete: :show

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
        |> moderation_log(details: &log_details/3, data: topic)
        |> redirect(to: ~p"/forums/#{topic.forum}/topics/#{topic}")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Unable to stick the topic!")
        |> redirect(to: ~p"/forums/#{topic.forum}/topics/#{topic}")
    end
  end

  def delete(conn, _opts) do
    topic = conn.assigns.topic

    case Topics.unstick_topic(topic) do
      {:ok, topic} ->
        conn
        |> put_flash(:info, "Topic successfully unstickied!")
        |> moderation_log(details: &log_details/3, data: topic)
        |> redirect(to: ~p"/forums/#{topic.forum}/topics/#{topic}")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Unable to unstick the topic!")
        |> redirect(to: ~p"/forums/#{topic.forum}/topics/#{topic}")
    end
  end

  defp log_details(conn, action, topic) do
    body =
      case action do
        :create -> "Stickied topic '#{topic.title}' in #{topic.forum.name}"
        :delete -> "Unstickied topic '#{topic.title}' in #{topic.forum.name}"
      end

    %{
      body: body,
      subject_path: ~p"/forums/#{topic.forum}/topics/#{topic}"
    }
  end
end
