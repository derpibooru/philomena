defmodule PhilomenaWeb.Topic.Post.ApproveController do
  use PhilomenaWeb, :controller

  alias Philomena.Posts.Post
  alias Philomena.Posts

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"forum_id" => forum_id, "topic_id" => topic_id, "post_id" => post_id}) do
    case Posts.create_post_approve(conn.assigns.actor, forum_id, topic_id, post_id) do
      {:ok, post} ->
        conn
        |> put_flash(:info, "Post successfully approved.")
        |> redirect(to: post_anchor(post))

      {:error, %Ecto.Changeset{data: %Post{} = post}} ->
        conn
        |> put_flash(:info, "Post has already been approved.")
        |> redirect(to: post_anchor(post))

      error ->
        error
    end
  end

  defp post_anchor(post) do
    ~p"/forums/#{post.topic.forum}/topics/#{post.topic}?#{[post_id: post.id]}" <>
      "#post_#{post.id}"
  end
end
