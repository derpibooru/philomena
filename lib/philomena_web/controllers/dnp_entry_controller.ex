defmodule PhilomenaWeb.DnpEntryController do
  use PhilomenaWeb, :controller

  # alias Philomena.DnpEntries
  alias Philomena.DnpEntries.DnpEntry
  alias Philomena.Textile.Renderer
  alias Philomena.Tags.Tag
  alias Philomena.Repo
  import Ecto.Query

  plug :load_and_authorize_resource, model: DnpEntry, only: [:show], preload: [:tag]

  def index(conn, _params) do
    dnp_entries =
      DnpEntry
      |> where(aasm_state: "listed")
      |> join(:inner, [d], t in Tag, on: d.tag_id == t.id)
      |> preload([:tag])
      |> order_by([d, t], asc: t.name_in_namespace)
      |> Repo.paginate(conn.assigns.scrivener)

    bodies =
      dnp_entries
      |> Enum.map(&%{body: &1.conditions || "-"})
      |> Renderer.render_collection()

    dnp_entries =
      %{dnp_entries | entries: Enum.zip(bodies, dnp_entries.entries)}

    render(conn, "index.html", layout_class: "layout--medium", dnp_entries: dnp_entries)
  end

  def show(conn, _params) do
    dnp_entry = conn.assigns.dnp_entry

    [conditions, reason, instructions] =
      Renderer.render_collection([
        %{body: dnp_entry.conditions || "-"},
        %{body: dnp_entry.reason || "-"},
        %{body: dnp_entry.instructions || "-"}
      ])

    render(conn, "show.html", dnp_entry: dnp_entry, conditions: conditions, reason: reason, instructions: instructions)
  end
end
