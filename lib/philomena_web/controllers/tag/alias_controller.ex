defmodule PhilomenaWeb.Tag.AliasController do
  use PhilomenaWeb, :controller

  alias Philomena.Tags

  action_fallback PhilomenaWeb.FallbackController

  def edit(conn, params) do
    with {:ok, {tag, changeset}} <-
           Tags.edit_tag_alias(conn.assigns.actor, params["tag_id"]) do
      render(conn, "edit.html", title: "Editing Tag Alias", tag: tag, changeset: changeset)
    end
  end

  def update(conn, %{"tag_id" => slug, "tag" => tag_params}) do
    case Tags.update_tag_alias(conn.assigns.actor, slug, tag_params) do
      {:ok, tag} ->
        conn
        |> put_flash(:info, "Tag alias queued.")
        |> redirect(to: ~p"/tags/#{tag}/alias/edit")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", tag: changeset.data, changeset: changeset)

      {:error, _} = error ->
        error
    end
  end

  def delete(conn, params) do
    case Tags.delete_tag_alias(conn.assigns.actor, params["tag_id"]) do
      {:ok, tag} ->
        conn
        |> put_flash(:info, "Tag dealias successful.")
        |> redirect(to: ~p"/tags/#{tag}")

      {:error, %Ecto.Changeset{data: tag}} ->
        conn
        |> put_flash(:error, "Tag is not aliased.")
        |> redirect(to: ~p"/tags/#{tag}/alias/edit")

      error ->
        error
    end
  end
end
