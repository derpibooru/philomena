defmodule PhilomenaWeb.Image.Comment.DeleteController do
  use PhilomenaWeb, :controller

  alias Philomena.Comments
  alias Philomena.Comments.Comment

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"image_id" => image_id, "comment_id" => comment_id}) do
    case Comments.create_comment_delete(conn.assigns.actor, image_id, comment_id) do
      {:ok, comment} ->
        conn
        |> put_flash(:info, "Comment successfully destroyed!")
        |> redirect(to: ~p"/images/#{comment.image_id}" <> "#comment_#{comment.id}")

      {:error, %Ecto.Changeset{data: %Comment{} = comment}} ->
        conn
        |> put_flash(:error, "Unable to destroy comment!")
        |> redirect(to: ~p"/images/#{comment.image_id}" <> "#comment_#{comment.id}")

      {:error, _} = error ->
        error
    end
  end
end
