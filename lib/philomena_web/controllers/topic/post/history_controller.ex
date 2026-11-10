defmodule PhilomenaWeb.Topic.Post.HistoryController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.MarkdownRenderer
  alias Philomena.Posts

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, %{"forum_id" => forum_id, "topic_id" => topic_id, "post_id" => post_id}) do
    with {:ok, {topic, post, versions}} <-
           Posts.list_post_history(conn.assigns.actor, forum_id, topic_id, post_id) do
      render(conn, "index.html",
        title: "Post History for Post #{post.id} - #{topic.title} - Forums",
        post: post,
        versions: MarkdownRenderer.render_version_diffs(versions)
      )
    end
  end
end
