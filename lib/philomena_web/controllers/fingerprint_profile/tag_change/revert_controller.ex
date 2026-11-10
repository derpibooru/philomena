defmodule PhilomenaWeb.FingerprintProfile.TagChange.RevertController do
  use PhilomenaWeb, :controller

  alias Philomena.TagChanges

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"fingerprint_profile_id" => fingerprint}) do
    with {:ok, _target} <-
           TagChanges.create_fingerprint_tag_change_revert(conn.assigns.actor, fingerprint) do
      conn
      |> put_flash(:info, "Reversion of tag changes enqueued.")
      |> redirect(external: conn.assigns.referrer)
    end
  end
end
