defmodule PhilomenaWeb.Topic.PostController do
  use PhilomenaWeb, :controller

  alias Philomena.{Forums.Forum, Topics.Topic, Posts}
  alias Philomena.Repo

  plug PhilomenaWeb.FilterBannedUsersPlug
  plug PhilomenaWeb.UserAttributionPlug
  plug PhilomenaWeb.CanaryMapPlug, create: :show, edit: :show, update: :show
  plug :load_and_authorize_resource, model: Forum, id_field: "short_name", id_name: "forum_id", persisted: true
  plug :load_topic

  def create(conn, %{"post" => post_params}) do
    attributes = conn.assigns.attributes
    forum = conn.assigns.forum
    topic = conn.assigns.topic
    user = conn.assigns.current_user

    case Posts.create_post(topic, user, attributes, post_params) do
      {:ok, %{post: post}} ->
        Posts.notify_post(post)
        Posts.reindex_post(post)

        conn
        |> put_flash(:info, "Post created successfully.")
        |> redirect(to: Routes.forum_topic_path(conn, :show, forum, topic, post_id: post.id) <> "#post_#{post.id}")

      _error ->
        conn
        |> put_flash(:error, "There was an error creating the post")
        |> redirect(external: conn.assigns.referrer)
    end
  end

  defp load_topic(%{params: %{"topic_id" => slug}} = conn, _args) do
    forum = conn.assigns.forum
    user = conn.assigns.current_user

    with topic when not is_nil(topic) <- Repo.get_by(Topic, slug: slug, forum_id: forum.id),
         true <- Canada.Can.can?(user, :show, topic)
    do
      conn
      |> assign(:topic, topic)
    else
      _ ->
        conn
        |> put_flash(:error, "Couldn't access that topic")
        |> redirect(external: conn.assigns.referrer)
    end
  end
end