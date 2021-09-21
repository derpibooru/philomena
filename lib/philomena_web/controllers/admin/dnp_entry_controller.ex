defmodule PhilomenaWeb.Admin.DnpEntryController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.TextRenderer
  alias Philomena.DnpEntries.DnpEntry
  alias Philomena.Repo
  import Ecto.Query

  plug :verify_authorized
  plug :load_resource, model: DnpEntry, only: [:show, :edit, :update]

  def index(conn, %{"states" => states}) when is_list(states) do
    DnpEntry
    |> where([d], d.aasm_state in ^states)
    |> load_entries(conn)
  end

  def index(conn, %{"q" => q}) when is_binary(q) do
    q = to_ilike(q)

    DnpEntry
    |> join(:inner, [d], _ in assoc(d, :tag))
    |> join(:inner, [d, _t], _ in assoc(d, :requesting_user))
    |> where(
      [d, t, u],
      ilike(u.name, ^q) or ilike(t.name, ^q) or ilike(d.reason, ^q) or ilike(d.conditions, ^q) or
        ilike(d.instructions, ^q)
    )
    |> load_entries(conn)
  end

  def index(conn, _params) do
    DnpEntry
    |> where([d], d.aasm_state in ["requested", "claimed", "rescinded", "acknowledged"])
    |> load_entries(conn)
  end

  defp load_entries(dnp_entries, conn) do
    dnp_entries =
      dnp_entries
      |> preload([:tag, :requesting_user, :modifying_user])
      |> order_by(desc: :updated_at)
      |> Repo.paginate(conn.assigns.scrivener)

    bodies =
      dnp_entries
      |> Enum.map(&%{body: &1.conditions, body_md: &1.conditions_md})
      |> TextRenderer.render_collection(conn)

    dnp_entries = %{dnp_entries | entries: Enum.zip(bodies, dnp_entries.entries)}

    render(conn, "index.html",
      layout_class: "layout--wide",
      title: "Admin - DNP Entries",
      dnp_entries: dnp_entries
    )
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :index, DnpEntry) do
      true -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp to_ilike(query), do: "%" <> query <> "%"
end
