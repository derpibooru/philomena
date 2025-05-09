defmodule PhilomenaWeb.Topic.Post.ApproveController do
  use PhilomenaWeb, :controller

  alias Philomena.Posts.Post
  alias Philomena.Posts

  plug PhilomenaWeb.CanaryMapPlug, create: :approve

  plug :load_and_authorize_resource,
    model: Post,
    id_name: "post_id",
    persisted: true,
    preload: [:topic, topic: :forum]

  def create(conn, _params) do
    post = conn.assigns.post
    user = conn.assigns.current_user

    case Posts.approve_post(post, user) do
      {:ok, post} ->
        conn
        |> put_flash(:info, "Post successfully approved.")
        |> moderation_log(details: &log_details/2, data: post)
        |> redirect(
          to:
            ~p"/forums/#{post.topic.forum}/topics/#{post.topic}?#{[post_id: post.id]}" <>
              "#post_#{post.id}"
        )

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Unable to approve post!")
        |> redirect(
          to:
            ~p"/forums/#{post.topic.forum}/topics/#{post.topic}?#{[post_id: post.id]}" <>
              "#post_#{post.id}"
        )
    end
  end

  defp log_details(_action, post) do
    %{
      body: "Approved forum post ##{post.id} in topic '#{post.topic.title}'",
      subject_path:
        ~p"/forums/#{post.topic.forum}/topics/#{post.topic}?#{[post_id: post.id]}" <>
          "#post_#{post.id}"
    }
  end
end
