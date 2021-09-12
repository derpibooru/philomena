defmodule PhilomenaWeb.Admin.ModNoteController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.TextRenderer
  alias Philomena.ModNotes.ModNote
  alias Philomena.Polymorphic
  alias Philomena.ModNotes
  alias Philomena.Repo
  import Ecto.Query

  plug :verify_authorized
  plug :load_resource, model: ModNote, only: [:edit, :update, :delete]
  plug :preload_association when action in [:edit, :update, :delete]

  def index(conn, %{"q" => q}) do
    ModNote
    |> where([m], ilike(m.body, ^"%#{q}%"))
    |> load_mod_notes(conn)
  end

  def index(conn, _params) do
    load_mod_notes(ModNote, conn)
  end

  defp load_mod_notes(queryable, conn) do
    mod_notes =
      queryable
      |> preload(:moderator)
      |> order_by(desc: :id)
      |> Repo.paginate(conn.assigns.scrivener)

    bodies = TextRenderer.render_collection(mod_notes, conn)
    preloaded = Polymorphic.load_polymorphic(mod_notes, notable: [notable_id: :notable_type])
    mod_notes = %{mod_notes | entries: Enum.zip(bodies, preloaded)}

    render(conn, "index.html", title: "Admin - Mod Notes", mod_notes: mod_notes)
  end

  def new(conn, %{"notable_type" => type, "notable_id" => id}) do
    changeset = ModNotes.change_mod_note(%ModNote{notable_type: type, notable_id: id})
    render(conn, "new.html", title: "New Mod Note", changeset: changeset)
  end

  def create(conn, %{"mod_note" => mod_note_params}) do
    case ModNotes.create_mod_note(conn.assigns.current_user, mod_note_params) do
      {:ok, _mod_note} ->
        conn
        |> put_flash(:info, "Successfully created mod note.")
        |> redirect(to: Routes.admin_mod_note_path(conn, :index))

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def edit(conn, _params) do
    changeset = ModNotes.change_mod_note(conn.assigns.mod_note)
    render(conn, "edit.html", title: "Editing Mod Note", changeset: changeset)
  end

  def update(conn, %{"mod_note" => mod_note_params}) do
    case ModNotes.update_mod_note(conn.assigns.mod_note, mod_note_params) do
      {:ok, _mod_note} ->
        conn
        |> put_flash(:info, "Successfully updated mod note.")
        |> redirect(to: Routes.admin_mod_note_path(conn, :index))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  def delete(conn, _params) do
    {:ok, _mod_note} = ModNotes.delete_mod_note(conn.assigns.mod_note)

    conn
    |> put_flash(:info, "Successfully deleted mod note.")
    |> redirect(to: Routes.admin_mod_note_path(conn, :index))
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :index, ModNote) do
      true -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  def preload_association(%{assigns: %{mod_note: mod_note}} = conn, _opts) do
    [mod_note] = Polymorphic.load_polymorphic([mod_note], notable: [notable_id: :notable_type])

    assign(conn, :mod_note, mod_note)
  end
end
