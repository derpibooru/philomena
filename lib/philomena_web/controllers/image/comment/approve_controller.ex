defmodule PhilomenaWeb.Image.Comment.ApproveController do
  use PhilomenaWeb, :controller

  alias Philomena.Comments

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"image_id" => image_id, "comment_id" => comment_id}) do
    case Comments.create_comment_approve(conn.assigns.actor, image_id, comment_id) do
      {:ok, comment} ->
        conn
        |> put_flash(:info, "Comment has been approved.")
        |> redirect(to: ~p"/images/#{comment.image_id}" <> "#comment_#{comment.id}")

      {:error, %{data: comment} = _changeset} ->
        conn
        |> put_flash(:info, "Comment has already been approved.")
        |> redirect(to: ~p"/images/#{comment.image_id}" <> "#comment_#{comment.id}")

      error ->
        error
    end
  end
end
