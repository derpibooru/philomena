defmodule PhilomenaWeb.Admin.ModNoteController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.MarkdownRenderer
  alias Philomena.ModNotes

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, params) do
    renderer = &MarkdownRenderer.render_collection(&1, conn)

    with {:ok, mod_notes} <-
           ModNotes.list_mod_notes(
             conn.assigns.actor,
             params,
             renderer,
             conn.assigns.scrivener
           ) do
      render(conn, "index.html", title: "Admin - Mod Notes", mod_notes: mod_notes)
    end
  end

  def new(conn, params) do
    with {:ok, changeset} <- ModNotes.new_mod_note(conn.assigns.actor, params) do
      render(conn, "new.html", title: "New Mod Note", changeset: changeset)
    end
  end

  def create(conn, %{"mod_note" => mod_note_params}) do
    case ModNotes.create_mod_note(conn.assigns.actor, mod_note_params) do
      {:ok, _mod_note} ->
        conn
        |> put_flash(:info, "Successfully created mod note.")
        |> redirect(to: ~p"/admin/mod_notes")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)

      {:error, _} = error ->
        error
    end
  end

  def edit(conn, %{"id" => id}) do
    with {:ok, {mod_note, changeset}} <-
           ModNotes.edit_mod_note(conn.assigns.actor, id) do
      render(conn, "edit.html",
        title: "Editing Mod Note",
        mod_note: mod_note,
        changeset: changeset
      )
    end
  end

  def update(conn, %{"id" => id, "mod_note" => mod_note_params}) do
    case ModNotes.update_mod_note(conn.assigns.actor, id, mod_note_params) do
      {:ok, _mod_note} ->
        conn
        |> put_flash(:info, "Successfully updated mod note.")
        |> redirect(to: ~p"/admin/mod_notes")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", mod_note: changeset.data, changeset: changeset)

      {:error, _} = error ->
        error
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, _mod_note} <- ModNotes.delete_mod_note(conn.assigns.actor, id) do
      conn
      |> put_flash(:info, "Successfully deleted mod note.")
      |> redirect(to: ~p"/admin/mod_notes")
    end
  end
end
