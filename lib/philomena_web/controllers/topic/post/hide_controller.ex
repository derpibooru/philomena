defmodule PhilomenaWeb.Topic.Post.HideController do
  use PhilomenaWeb, :controller

  alias Philomena.Posts.Post
  alias Philomena.Posts

  plug PhilomenaWeb.CanaryMapPlug, create: :hide, delete: :hide

  plug :load_and_authorize_resource,
    model: Post,
    id_name: "post_id",
    persisted: true,
    preload: [:topic, topic: :forum]

  def create(conn, %{"post" => post_params}) do
    post = conn.assigns.post
    user = conn.assigns.current_user

    case Posts.hide_post(post, post_params, user) do
      {:ok, post} ->
        conn
        |> put_flash(:info, "Post successfully deleted.")
        |> moderation_log(details: &log_details/2, data: post)
        |> redirect(
          to:
            ~p"/forums/#{post.topic.forum}/topics/#{post.topic}?#{[post_id: post.id]}" <>
              "#post_#{post.id}"
        )

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Unable to delete post!")
        |> redirect(
          to:
            ~p"/forums/#{post.topic.forum}/topics/#{post.topic}?#{[post_id: post.id]}" <>
              "#post_#{post.id}"
        )
    end
  end

  def delete(conn, _params) do
    post = conn.assigns.post

    case Posts.unhide_post(post) do
      {:ok, post} ->
        conn
        |> put_flash(:info, "Post successfully restored.")
        |> moderation_log(details: &log_details/2, data: post)
        |> redirect(
          to:
            ~p"/forums/#{post.topic.forum}/topics/#{post.topic}?#{[post_id: post.id]}" <>
              "#post_#{post.id}"
        )

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Unable to restore post!")
        |> redirect(
          to:
            ~p"/forums/#{post.topic.forum}/topics/#{post.topic}?#{[post_id: post.id]}" <>
              "#post_#{post.id}"
        )
    end
  end

  defp log_details(action, post) do
    body =
      case action do
        :create ->
          "Deleted forum post ##{post.id} in topic '#{post.topic.title}' (#{post.deletion_reason})"

        :delete ->
          "Restored forum post ##{post.id} in topic '#{post.topic.title}'"
      end

    %{
      body: body,
      subject_path:
        ~p"/forums/#{post.topic.forum}/topics/#{post.topic}?#{[post_id: post.id]}" <>
          "#post_#{post.id}"
    }
  end
end
