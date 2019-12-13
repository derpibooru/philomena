defmodule PhilomenaWeb.Topic.PostController do
  use PhilomenaWeb, :controller

  alias Philomena.{Forums.Forum, Topics.Topic, Posts.Post}
  alias Philomena.Posts
  alias Philomena.UserStatistics
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.FilterBannedUsersPlug
  plug PhilomenaWeb.UserAttributionPlug
  plug PhilomenaWeb.CanaryMapPlug, create: :show, edit: :show, update: :show
  plug :load_and_authorize_resource, model: Forum, id_field: "short_name", id_name: "forum_id", persisted: true

  plug :load_topic
  plug PhilomenaWeb.CanaryMapPlug, create: :create_post, edit: :create_post, update: :create_post
  plug :authorize_resource, model: Topic, id_field: "slug", id_name: "topic_id", persisted: true

  plug PhilomenaWeb.CanaryMapPlug, edit: :edit, update: :edit
  plug :load_and_authorize_resource, model: Post, only: [:edit, :update], preload: [topic: :forum]

  def create(conn, %{"post" => post_params}) do
    attributes = conn.assigns.attributes
    forum = conn.assigns.forum
    topic = conn.assigns.topic

    case Posts.create_post(topic, attributes, post_params) do
      {:ok, %{post: post}} ->
        Posts.notify_post(post)
        Posts.reindex_post(post)
        UserStatistics.inc_stat(conn.assigns.current_user, :forum_posts)

        conn
        |> put_flash(:info, "Post created successfully.")
        |> redirect(to: Routes.forum_topic_path(conn, :show, forum, topic, post_id: post.id) <> "#post_#{post.id}")

      _error ->
        conn
        |> put_flash(:error, "There was an error creating the post")
        |> redirect(external: conn.assigns.referrer)
    end
  end

  def edit(conn, _params) do
    changeset = Posts.change_post(conn.assigns.post)
    render(conn, "edit.html", changeset: changeset)
  end

  def update(conn, %{"post" => post_params}) do
    post = conn.assigns.post
    user = conn.assigns.current_user

    case Posts.update_post(post, user, post_params) do
      {:ok, _post} ->
        Posts.reindex_post(post)

        conn
        |> put_flash(:info, "Post successfully edited.")
        |> redirect(to: Routes.forum_topic_path(conn, :show, post.topic.forum, post.topic, post_id: post.id) <> "#post_#{post.id}")

      {:error, :post, changeset, _changes} ->
        render(conn, "edit.html", post: conn.assigns.post, changeset: changeset)
    end
  end

  defp load_topic(conn, _opts) do
    user = conn.assigns.current_user
    forum = conn.assigns.forum
    topic =
      Topic
      |> where(forum_id: ^forum.id, slug: ^conn.params["topic_id"])
      |> preload(:forum)
      |> Repo.one()

    cond do
      is_nil(topic) ->
        PhilomenaWeb.NotFoundPlug.call(conn)

      not Canada.Can.can?(user, :show, topic) ->
        PhilomenaWeb.NotAuthorizedPlug.call(conn)

      true ->
        Plug.Conn.assign(conn, :topic, topic)
    end
  end
end
