defmodule PhilomenaWeb.Tag.ImageController do
  use PhilomenaWeb, :controller

  alias Philomena.Tags

  action_fallback PhilomenaWeb.FallbackController

  def edit(conn, params) do
    with {:ok, {tag, changeset}} <-
           Tags.edit_tag_image(conn.assigns.actor, params["tag_id"]) do
      render(conn, "edit.html",
        title: "Editing Tag Spoiler Image",
        tag: tag,
        changeset: changeset
      )
    end
  end

  def update(conn, %{"tag_id" => slug, "tag" => tag_params}) do
    upload = PhilomenaMedia.Upload.cast(tag_params, "image")

    case Tags.update_tag_image(conn.assigns.actor, slug, upload) do
      {:ok, tag} ->
        conn
        |> put_flash(:info, "Tag image successfully updated.")
        |> redirect(to: ~p"/tags/#{tag}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", tag: changeset.data, changeset: changeset)

      {:error, _} = error ->
        error
    end
  end

  def delete(conn, params) do
    with {:ok, tag} <- Tags.delete_tag_image(conn.assigns.actor, params["tag_id"]) do
      conn
      |> put_flash(:info, "Tag image successfully removed.")
      |> redirect(to: ~p"/tags/#{tag}")
    end
  end
end
