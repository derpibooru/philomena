defmodule PhilomenaWeb.DnpEntryController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.MarkdownRenderer
  alias Philomena.DnpEntries
  alias Philomena.DnpEntries.{DnpEntryForm, DnpEntryPage}

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, params) do
    listing =
      DnpEntries.list_dnp_entries(conn.assigns.actor, params, conn.assigns.scrivener)

    bodies =
      listing.dnp_entries
      |> Enum.map(&%{body: &1.conditions || "-"})
      |> MarkdownRenderer.render_collection(conn)

    dnp_entries = %{listing.dnp_entries | entries: Enum.zip(bodies, listing.dnp_entries.entries)}

    render(conn, "index.html",
      title: "Do-Not-Post List",
      layout_class: "layout--medium",
      dnp_entries: dnp_entries,
      status_column: listing.status_column,
      linked_tags: listing.linked_tags
    )
  end

  def show(conn, %{"id" => id}) do
    renderer = &MarkdownRenderer.render_collection(&1, conn)

    with {:ok, %DnpEntryPage{dnp_entry: dnp_entry, mod_notes: mod_notes}} <-
           DnpEntries.show_dnp_entry(conn.assigns.actor, id, renderer) do
      [conditions, reason, instructions] =
        MarkdownRenderer.render_collection(
          [
            %{body: dnp_entry.conditions || "-"},
            %{body: dnp_entry.reason || "-"},
            %{body: dnp_entry.instructions || "-"}
          ],
          conn
        )

      assigns = [
        title: "Showing DNP Listing",
        dnp_entry: dnp_entry,
        conditions: conditions,
        reason: reason,
        instructions: instructions
      ]

      assigns = if is_nil(mod_notes), do: assigns, else: [{:mod_notes, mod_notes} | assigns]

      render(conn, "show.html", assigns)
    end
  end

  def new(conn, params) do
    with {:ok, %DnpEntryForm{changeset: changeset, selectable_tags: selectable_tags}} <-
           DnpEntries.new_dnp_entry(conn.assigns.actor, params) do
      render(conn, "new.html",
        title: "New DNP Listing",
        changeset: changeset,
        selectable_tags: selectable_tags
      )
    end
  end

  def create(conn, params) do
    case DnpEntries.create_dnp_entry(conn.assigns.actor, params["dnp_entry"]) do
      {:ok, dnp_entry} ->
        conn
        |> put_flash(:info, "Successfully submitted DNP request.")
        |> redirect(to: ~p"/dnp/#{dnp_entry}")

      {:error, %DnpEntryForm{changeset: changeset, selectable_tags: selectable_tags}} ->
        render(conn, "new.html", changeset: changeset, selectable_tags: selectable_tags)

      {:error, _} = error ->
        error
    end
  end

  def edit(conn, %{"id" => id}) do
    with {:ok,
          %DnpEntryForm{
            dnp_entry: dnp_entry,
            changeset: changeset,
            selectable_tags: selectable_tags
          }} <-
           DnpEntries.edit_dnp_entry(conn.assigns.actor, id) do
      render(conn, "edit.html",
        title: "Editing DNP Listing",
        dnp_entry: dnp_entry,
        changeset: changeset,
        selectable_tags: selectable_tags
      )
    end
  end

  def update(conn, %{"id" => id} = params) do
    case DnpEntries.update_dnp_entry(conn.assigns.actor, id, params["dnp_entry"]) do
      {:ok, dnp_entry} ->
        conn
        |> put_flash(:info, "Successfully updated DNP request.")
        |> redirect(to: ~p"/dnp/#{dnp_entry}")

      {:error,
       %DnpEntryForm{
         dnp_entry: dnp_entry,
         changeset: changeset,
         selectable_tags: selectable_tags
       }} ->
        render(conn, "edit.html",
          dnp_entry: dnp_entry,
          changeset: changeset,
          selectable_tags: selectable_tags
        )

      {:error, _} = error ->
        error
    end
  end
end
