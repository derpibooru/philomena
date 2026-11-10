defmodule PhilomenaWeb.Admin.DnpEntryController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.MarkdownRenderer
  alias Philomena.DnpEntries

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, params) do
    with {:ok, dnp_entries, changeset} <-
           DnpEntries.list_admin_dnp_entries(
             conn.assigns.actor,
             query_param(params, "eq"),
             conn.assigns.scrivener
           ) do
      bodies =
        dnp_entries
        |> Enum.map(&%{body: &1.conditions})
        |> MarkdownRenderer.render_collection(conn)

      dnp_entries = %{dnp_entries | entries: Enum.zip(bodies, dnp_entries.entries)}

      render(conn, "index.html",
        layout_class: "layout--wide",
        title: "Admin - DNP Entries",
        dnp_entries: dnp_entries,
        changeset: changeset
      )
    end
  end
end
