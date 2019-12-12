defmodule PhilomenaWeb.DnpEntryController do
  use PhilomenaWeb, :controller

  alias Philomena.DnpEntries.DnpEntry
  alias Philomena.Textile.Renderer
  alias Philomena.DnpEntries
  alias Philomena.Tags.Tag
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.FilterBannedUsersPlug when action in [:new, :create]
  plug :load_and_authorize_resource, model: DnpEntry, only: [:show, :edit, :update], preload: [:tag]

  def index(%{assigns: %{current_user: user}} = conn, %{"mine" => _mine}) when not is_nil(user) do
    DnpEntry
    |> where(requesting_user_id: ^user.id)
    |> preload(:tag)
    |> order_by(asc: :created_at)
    |> load_entries(conn, true)
  end

  def index(conn, _params) do
    DnpEntry
    |> where(aasm_state: "listed")
    |> join(:inner, [d], t in Tag, on: d.tag_id == t.id)
    |> preload(:tag)
    |> order_by([_d, t], asc: t.name_in_namespace)
    |> load_entries(conn, false)
  end

  defp load_entries(dnp_entries, conn, status) do
    dnp_entries = Repo.paginate(dnp_entries, conn.assigns.scrivener)

    bodies =
      dnp_entries
      |> Enum.map(&%{body: &1.conditions || "-"})
      |> Renderer.render_collection(conn)

    dnp_entries =
      %{dnp_entries | entries: Enum.zip(bodies, dnp_entries.entries)}

    render(conn, "index.html", layout_class: "layout--medium", dnp_entries: dnp_entries, status_column: status)
  end

  def show(conn, _params) do
    dnp_entry = conn.assigns.dnp_entry

    [conditions, reason, instructions] =
      Renderer.render_collection(
        [
          %{body: dnp_entry.conditions || "-"},
          %{body: dnp_entry.reason || "-"},
          %{body: dnp_entry.instructions || "-"}
        ],
        conn
      )

    render(conn, "show.html", dnp_entry: dnp_entry, conditions: conditions, reason: reason, instructions: instructions)
  end

  def new(conn, _params) do
    changeset = DnpEntries.change_dnp_entry(%DnpEntry{})
    render(conn, "new.html", changeset: changeset, selectable_tags: selectable_tags(conn))
  end

  def create(conn, %{"dnp_entry" => dnp_entry_params}) do
    case DnpEntries.create_dnp_entry(conn.assigns.current_user, selectable_tags(conn), dnp_entry_params) do
      {:ok, dnp_entry} ->
        conn
        |> put_flash(:info, "Successfully submitted DNP request.")
        |> redirect(to: Routes.dnp_entry_path(conn, :show, dnp_entry))

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset, selectable_tags: selectable_tags(conn))
    end
  end

  def edit(conn, _params) do
    changeset = DnpEntries.change_dnp_entry(conn.assigns.dnp_entry)
    render(conn, "edit.html", changeset: changeset, selectable_tags: selectable_tags(conn))
  end

  def update(conn, %{"dnp_entry" => dnp_entry_params}) do
    case DnpEntries.update_dnp_entry(conn.assigns.dnp_entry, selectable_tags(conn), dnp_entry_params) do
      {:ok, dnp_entry} ->
        conn
        |> put_flash(:info, "Successfully submupdateditted DNP request.")
        |> redirect(to: Routes.dnp_entry_path(conn, :show, dnp_entry))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset, selectable_tags: selectable_tags(conn))
    end
  end

  defp selectable_tags(conn) do
    case not is_nil(conn.params["tag_id"]) and Canada.Can.can?(conn.assigns.current_user, :index, DnpEntry) do
      true -> [Repo.get!(Tag, conn.params["tag_id"])]
      false -> linked_tags(conn)
    end
  end

  defp linked_tags(conn) do
    conn.assigns.current_user
    |> Repo.preload(:linked_tags)
    |> Map.get(:linked_tags)
  end
end
