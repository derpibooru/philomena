defmodule PhilomenaWeb.Profile.FpHistoryController do
  use PhilomenaWeb, :controller

  alias Philomena.Profiles

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, %{"profile_id" => slug}) do
    with {:ok, history} <-
           Profiles.list_profile_fingerprint_history(
             conn.assigns.actor,
             slug,
             conn.assigns.scrivener
           ) do
      render(conn, "index.html",
        title: "Fingerprint History for `#{history.user.name}'",
        user: history.user,
        user_fingerprints: history.user_fingerprints,
        other_users: history.other_users
      )
    end
  end
end
