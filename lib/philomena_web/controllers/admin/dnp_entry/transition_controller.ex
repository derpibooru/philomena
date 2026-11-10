defmodule PhilomenaWeb.Admin.DnpEntry.TransitionController do
  use PhilomenaWeb, :controller

  alias Philomena.DnpEntries

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"dnp_entry_id" => dnp_entry_id} = params) do
    new_state = params["state"]

    case DnpEntries.create_dnp_entry_transition(conn.assigns.actor, dnp_entry_id, new_state) do
      {:ok, dnp_entry} ->
        conn
        |> put_flash(:info, "Successfully updated DNP entry.")
        |> redirect(to: ~p"/dnp/#{dnp_entry}")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_flash(:error, "Failed to update DNP entry!")
        |> redirect(to: ~p"/dnp/#{changeset.data}")

      {:error, _} = error ->
        error
    end
  end
end
