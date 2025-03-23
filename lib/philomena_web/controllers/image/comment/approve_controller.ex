defmodule PhilomenaWeb.Image.Comment.ApproveController do
  use PhilomenaWeb, :controller

  alias Philomena.Comments.Comment
  alias Philomena.Comments
  alias Philomena.UserStatistics

  plug PhilomenaWeb.CanaryMapPlug, create: :approve

  plug :load_and_authorize_resource,
    model: Comment,
    id_name: "comment_id",
    persisted: true,
    preload: [:user]

  def create(conn, _params) do
    comment = conn.assigns.comment

    {:ok, _comment} = Comments.approve_comment(comment, conn.assigns.current_user)

    UserStatistics.inc_stat(comment.user, :comments_posted)

    conn
    |> put_flash(:info, "Comment has been approved.")
    |> moderation_log(details: &log_details/2, data: comment)
    |> redirect(to: ~p"/images/#{comment.image_id}" <> "#comment_#{comment.id}")
  end

  defp log_details(_action, comment) do
    %{
      body: "Approved comment on image #{comment.image_id}",
      subject_path: ~p"/images/#{comment.image_id}" <> "#comment_#{comment.id}"
    }
  end
end
