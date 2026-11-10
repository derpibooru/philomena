defmodule PhilomenaWeb.Image.TagLockController do
  use PhilomenaWeb, :controller

  alias Philomena.Images

  action_fallback PhilomenaWeb.FallbackController

  def show(conn, params) do
    with {:ok, image} <-
           Images.load_hidable_image(conn.assigns.actor, params["image_id"],
             preload: :locked_tags
           ) do
      changeset = Images.change_image(image)
      render(conn, "show.html", title: "Locking image tags", image: image, changeset: changeset)
    end
  end

  def update(conn, %{"image" => image_attrs} = params) do
    with {:ok, image} <-
           Images.update_image_locked_tags(conn.assigns.actor, params["image_id"], image_attrs) do
      conn
      |> put_flash(:info, "Successfully updated list of locked tags.")
      |> redirect(to: ~p"/images/#{image}")
    end
  end

  def create(conn, params) do
    with {:ok, image} <-
           Images.update_image_tag_lock(conn.assigns.actor, params["image_id"], true) do
      conn
      |> put_flash(:info, "Successfully locked tags and sources.")
      |> redirect(to: ~p"/images/#{image}")
    end
  end

  def delete(conn, params) do
    with {:ok, image} <-
           Images.update_image_tag_lock(conn.assigns.actor, params["image_id"], false) do
      conn
      |> put_flash(:info, "Successfully unlocked tags and sources.")
      |> redirect(to: ~p"/images/#{image}")
    end
  end
end
