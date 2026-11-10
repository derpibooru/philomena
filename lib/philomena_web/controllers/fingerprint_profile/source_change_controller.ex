defmodule PhilomenaWeb.FingerprintProfile.SourceChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.SourceChanges
  alias Philomena.SourceChanges.SourceChangePage

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, %{"fingerprint_profile_id" => fingerprint} = params) do
    case SourceChanges.list_fingerprint_source_changes(
           conn.assigns.actor,
           fingerprint,
           params,
           conn.assigns.scrivener
         ) do
      {:ok, %SourceChangePage{target: fingerprint, source_changes: source_changes}, changeset} ->
        render(conn, "index.html",
          title: "Source Changes for Fingerprint `#{fingerprint}'",
          fingerprint: fingerprint,
          source_changes: source_changes,
          changeset: changeset
        )

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_flash(:error, "Invalid source change filter.")
        |> redirect(to: "/")

      error ->
        error
    end
  end
end
