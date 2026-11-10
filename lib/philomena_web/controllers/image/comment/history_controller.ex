defmodule PhilomenaWeb.Image.Comment.HistoryController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.MarkdownRenderer
  alias Philomena.Comments

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, %{"image_id" => image_id, "comment_id" => comment_id}) do
    with {:ok, history} <-
           Comments.list_comment_history(conn.assigns.actor, image_id, comment_id) do
      render(conn, "index.html",
        title: "Comment History for comment #{history.comment.id} on image #{history.image.id}",
        comment: history.comment,
        versions: MarkdownRenderer.render_version_diffs(history.versions)
      )
    end
  end
end
