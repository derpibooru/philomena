defmodule PhilomenaWeb.Admin.DnpEntry.TransitionController do
  use PhilomenaWeb, :controller

  alias Philomena.DnpEntries.DnpEntry
  alias Philomena.DnpEntries

  plug :verify_authorized
  plug :load_resource, model: DnpEntry, only: [:create], id_name: "dnp_entry_id", persisted: true

  def create(conn, %{"state" => new_state}) do
    case DnpEntries.transition_dnp_entry(
           conn.assigns.dnp_entry,
           conn.assigns.current_user,
           new_state
         ) do
      {:ok, dnp_entry} ->
        conn
        |> put_flash(:info, "Successfully updated DNP entry.")
        |> redirect(to: Routes.dnp_entry_path(conn, :show, dnp_entry))

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Failed to update DNP entry!")
        |> redirect(to: Routes.dnp_entry_path(conn, :show, conn.assigns.dnp_entry))
    end
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :index, DnpEntry) do
      true -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
