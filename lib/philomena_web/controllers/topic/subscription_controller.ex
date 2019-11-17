defmodule PhilomenaWeb.Topic.SubscriptionController do
  use PhilomenaWeb, :controller

  alias Philomena.{Topics, Topics.Topic, Forums.Forum}
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.CanaryMapPlug, create: :show, delete: :show
  plug :load_and_authorize_resource, model: Forum, id_name: "forum_id", id_field: "short_name", persisted: true

  def create(conn, %{"topic_id" => slug}) do
    topic = load_topic(conn, slug)
    user = conn.assigns.current_user

    case Topics.create_subscription(topic, user) do
      {:ok, _subscription} ->
        render(conn, "_subscription.html", forum: conn.assigns.forum, topic: topic, watching: true, layout: false)

      {:error, _changeset} ->
        render(conn, "_error.html", layout: false)
    end
  end

  def delete(conn, %{"topic_id" => slug}) do
    topic = load_topic(conn, slug)
    user = conn.assigns.current_user

    case Topics.delete_subscription(topic, user) do
      {:ok, _subscription} ->
        render(conn, "_subscription.html", forum: conn.assigns.forum, topic: topic, watching: false, layout: false)

      {:error, _changeset} ->
        render(conn, "_error.html", layout: false)
    end
  end

  defp load_topic(conn, slug) do
    forum = conn.assigns.forum

    Topic
    |> where(forum_id: ^forum.id, slug: ^slug, hidden_from_users: false)
    |> preload(:user)
    |> Repo.one()
  end
end