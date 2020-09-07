defmodule PhilomenaWeb.Tag.ImageController do
  use PhilomenaWeb, :controller

  alias Philomena.Tags.Tag
  alias Philomena.Tags

  plug PhilomenaWeb.CanaryMapPlug, update: :edit, delete: :edit

  plug :load_and_authorize_resource,
    model: Tag,
    id_name: "tag_id",
    id_field: "slug",
    preload: [:implied_tags],
    persisted: true

  def edit(conn, _params) do
    changeset = Tags.change_tag(conn.assigns.tag)
    render(conn, "edit.html", title: "Editing Tag Spoiler Image", changeset: changeset)
  end

  def update(conn, %{"tag" => tag_params}) do
    case Tags.update_tag_image(conn.assigns.tag, tag_params) do
      {:ok, tag} ->
        conn
        |> put_flash(:info, "Tag image successfully updated.")
        |> redirect(to: Routes.tag_path(conn, :show, tag))

      {:error, :tag, changeset, _changes} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  def delete(conn, _params) do
    {:ok, _tag} = Tags.remove_tag_image(conn.assigns.tag)

    conn
    |> put_flash(:info, "Tag image successfully removed.")
    |> redirect(to: Routes.tag_path(conn, :show, conn.assigns.tag))
  end
end
