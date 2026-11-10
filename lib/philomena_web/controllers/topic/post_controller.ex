defmodule PhilomenaWeb.Topic.PostController do
  use PhilomenaWeb, :controller

  alias Philomena.Posts
  alias PhilomenaWeb.RateLimitedResponse

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"forum_id" => forum_id, "topic_id" => topic_id} = params) do
    case Posts.create_post(conn.assigns.actor, forum_id, topic_id, params["post"]) do
      {:ok, post} ->
        conn
        |> put_flash(:info, "Post created successfully.")
        |> redirect(
          to:
            ~p"/forums/#{post.topic.forum}/topics/#{post.topic}?#{[post_id: post.id]}" <>
              "#post_#{post.id}"
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        post = changeset.data

        conn
        |> put_flash(:error, "There was an error creating the post")
        |> redirect(to: ~p"/forums/#{post.topic.forum}/topics/#{post.topic}")

      {:error, :rate_limited} ->
        RateLimitedResponse.call(conn, "You may only make a post once every 15 seconds.")

      error ->
        error
    end
  end

  def edit(conn, %{"forum_id" => forum_id, "topic_id" => topic_id, "id" => id}) do
    with {:ok, changeset} <-
           Posts.edit_post(conn.assigns.actor, forum_id, topic_id, id) do
      render(conn, "edit.html", title: "Editing Post", post: changeset.data, changeset: changeset)
    end
  end

  def update(conn, %{"forum_id" => forum_id, "topic_id" => topic_id, "id" => id} = params) do
    case Posts.update_post(conn.assigns.actor, forum_id, topic_id, id, params["post"]) do
      {:ok, post} ->
        conn
        |> put_flash(:info, "Post successfully edited.")
        |> redirect(
          to:
            ~p"/forums/#{post.topic.forum}/topics/#{post.topic}?#{[post_id: post.id]}" <>
              "#post_#{post.id}"
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", post: changeset.data, changeset: changeset)

      error ->
        error
    end
  end
end
