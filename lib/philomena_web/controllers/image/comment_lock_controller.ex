defmodule PhilomenaWeb.Image.CommentLockController do
  use PhilomenaWeb, :controller

  alias Philomena.Images

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, params) do
    with {:ok, image} <-
           Images.update_image_comment_lock(conn.assigns.actor, params["image_id"], true) do
      conn
      |> put_flash(:info, "Successfully locked comments.")
      |> redirect(to: ~p"/images/#{image}")
    end
  end

  def delete(conn, params) do
    with {:ok, image} <-
           Images.update_image_comment_lock(conn.assigns.actor, params["image_id"], false) do
      conn
      |> put_flash(:info, "Successfully unlocked comments.")
      |> redirect(to: ~p"/images/#{image}")
    end
  end
end
