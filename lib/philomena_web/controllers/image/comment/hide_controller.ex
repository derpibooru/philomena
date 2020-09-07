defmodule PhilomenaWeb.Image.Comment.HideController do
  use PhilomenaWeb, :controller

  alias Philomena.Comments.Comment
  alias Philomena.Comments

  plug PhilomenaWeb.CanaryMapPlug, create: :hide, delete: :hide
  plug :load_and_authorize_resource, model: Comment, id_name: "comment_id", persisted: true

  def create(conn, %{"comment" => comment_params}) do
    comment = conn.assigns.comment
    user = conn.assigns.current_user

    case Comments.hide_comment(comment, comment_params, user) do
      {:ok, comment} ->
        conn
        |> put_flash(:info, "Comment successfully hidden!")
        |> redirect(
          to: Routes.image_path(conn, :show, comment.image_id) <> "#comment_#{comment.id}"
        )

      _error ->
        conn
        |> put_flash(:error, "Unable to hide comment!")
        |> redirect(
          to: Routes.image_path(conn, :show, comment.image_id) <> "#comment_#{comment.id}"
        )
    end
  end

  def delete(conn, _params) do
    comment = conn.assigns.comment

    case Comments.unhide_comment(comment) do
      {:ok, comment} ->
        conn
        |> put_flash(:info, "Comment successfully unhidden!")
        |> redirect(
          to: Routes.image_path(conn, :show, comment.image_id) <> "#comment_#{comment.id}"
        )

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Unable to unhide comment!")
        |> redirect(
          to: Routes.image_path(conn, :show, comment.image_id) <> "#comment_#{comment.id}"
        )
    end
  end
end
