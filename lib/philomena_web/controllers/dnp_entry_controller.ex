defmodule PhilomenaWeb.DnpEntryController do
  use PhilomenaWeb, :controller

  alias Philomena.DnpEntries.DnpEntry
  alias PhilomenaWeb.MarkdownRenderer
  alias Philomena.DnpEntries
  alias Philomena.Tags.Tag
  alias Philomena.ModNotes.ModNote
  alias Philomena.Polymorphic
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.FilterBannedUsersPlug when action in [:new, :create]
  plug :set_tags when action in [:new, :create, :edit, :update, :create]

  plug :load_and_authorize_resource,
    model: DnpEntry,
    only: [:show, :edit, :update],
    preload: [:tag]

  plug :set_mod_notes when action in [:show]

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
    linked_tags = linked_tags(conn)

    bodies =
      dnp_entries
      |> Enum.map(&%{body: &1.conditions || "-"})
      |> MarkdownRenderer.render_collection(conn)

    dnp_entries = %{dnp_entries | entries: Enum.zip(bodies, dnp_entries.entries)}

    render(conn, "index.html",
      title: "Do-Not-Post List",
      layout_class: "layout--medium",
      dnp_entries: dnp_entries,
      status_column: status,
      linked_tags: linked_tags
    )
  end

  def show(conn, _params) do
    dnp_entry = conn.assigns.dnp_entry

    [conditions, reason, instructions] =
      MarkdownRenderer.render_collection(
        [
          %{body: dnp_entry.conditions || "-"},
          %{body: dnp_entry.reason || "-"},
          %{body: dnp_entry.instructions || "-"}
        ],
        conn
      )

    render(conn, "show.html",
      title: "Showing DNP Listing",
      dnp_entry: dnp_entry,
      conditions: conditions,
      reason: reason,
      instructions: instructions
    )
  end

  def new(conn, _params) do
    changeset = DnpEntries.change_dnp_entry(%DnpEntry{})

    render(conn, "new.html",
      title: "New DNP Listing",
      changeset: changeset
    )
  end

  def create(conn, %{"dnp_entry" => dnp_entry_params}) do
    case DnpEntries.create_dnp_entry(
           conn.assigns.current_user,
           conn.assigns.selectable_tags,
           dnp_entry_params
         ) do
      {:ok, dnp_entry} ->
        conn
        |> put_flash(:info, "Successfully submitted DNP request.")
        |> redirect(to: Routes.dnp_entry_path(conn, :show, dnp_entry))

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def edit(conn, _params) do
    changeset = DnpEntries.change_dnp_entry(conn.assigns.dnp_entry)

    render(conn, "edit.html",
      title: "Editing DNP Listing",
      changeset: changeset
    )
  end

  def update(conn, %{"dnp_entry" => dnp_entry_params}) do
    case DnpEntries.update_dnp_entry(
           conn.assigns.dnp_entry,
           conn.assigns.selectable_tags,
           dnp_entry_params
         ) do
      {:ok, dnp_entry} ->
        conn
        |> put_flash(:info, "Successfully updated DNP request.")
        |> redirect(to: Routes.dnp_entry_path(conn, :show, dnp_entry))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  defp selectable_tags(conn) do
    case present?(conn.params["tag_id"]) and
           Canada.Can.can?(conn.assigns.current_user, :index, DnpEntry) do
      true -> [Repo.get!(Tag, conn.params["tag_id"])]
      false -> linked_tags(conn)
    end
  end

  defp linked_tags(%{assigns: %{current_user: user}}) when not is_nil(user) do
    user
    |> Repo.preload(:linked_tags)
    |> Map.get(:linked_tags)
  end

  defp linked_tags(_), do: []

  defp present?(nil), do: false
  defp present?(""), do: false
  defp present?(_), do: true

  defp set_mod_notes(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :index, ModNote) do
      true ->
        dnp_entry = conn.assigns.dnp_entry

        mod_notes =
          ModNote
          |> where(notable_type: "DnpEntry", notable_id: ^dnp_entry.id)
          |> order_by(desc: :id)
          |> preload(:moderator)
          |> Repo.all()
          |> Polymorphic.load_polymorphic(notable: [notable_id: :notable_type])

        mod_notes =
          mod_notes
          |> MarkdownRenderer.render_collection(conn)
          |> Enum.zip(mod_notes)

        assign(conn, :mod_notes, mod_notes)

      _false ->
        conn
    end
  end

  defp set_tags(conn, _opts) do
    tags = selectable_tags(conn)

    case tags do
      [] ->
        PhilomenaWeb.NotAuthorizedPlug.call(conn)

      _ ->
        assign(conn, :selectable_tags, tags)
    end
  end
end
