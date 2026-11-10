defmodule PhilomenaWeb.Profile.AliasController do
  use PhilomenaWeb, :controller

  alias Philomena.Users

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, %{"profile_id" => slug}) do
    with {:ok, matches} <- Users.list_profile_aliases(conn.assigns.actor, slug) do
      render(conn, "index.html",
        title: "Potential Aliases for `#{matches.user.name}'",
        both_matches: matches.both_matches,
        ip_matches: matches.ip_matches,
        fp_matches: matches.fp_matches
      )
    end
  end
end
