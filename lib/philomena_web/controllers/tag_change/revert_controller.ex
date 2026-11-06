defmodule PhilomenaWeb.TagChange.RevertController do
  use PhilomenaWeb, :controller

  alias Philomena.TagChanges

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, params) do
    case TagChanges.create_tag_change_revert(conn.assigns.actor, params) do
      {:ok, tag_changes} ->
        conn
        |> put_flash(:info, "Successfully reverted #{length(tag_changes)} tag changes.")
        |> redirect(external: conn.assigns.referrer)

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_flash(:error, "Couldn't revert those tag changes!")
        |> redirect(external: conn.assigns.referrer)

      error ->
        error
    end
  end
end
