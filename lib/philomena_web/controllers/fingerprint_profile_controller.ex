defmodule PhilomenaWeb.FingerprintProfileController do
  use PhilomenaWeb, :controller

  alias Philomena.UserFingerprints

  action_fallback PhilomenaWeb.FallbackController

  def show(conn, %{"id" => fingerprint}) do
    with {:ok, profile} <-
           UserFingerprints.show_fingerprint_profile(conn.assigns.actor, fingerprint) do
      render(conn, "show.html",
        title: "#{profile.fingerprint}'s fingerprint profile",
        fingerprint: profile.fingerprint,
        user_fps: profile.user_fingerprints,
        fingerprint_bans: profile.fingerprint_bans
      )
    end
  end
end
