defmodule PhilomenaWeb.Admin.ArtistLinkController do
  use PhilomenaWeb, :controller

  alias Philomena.ArtistLinks

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, params) do
    with {:ok, artist_links, changeset} <-
           ArtistLinks.list_admin_artist_links(
             conn.assigns.actor,
             query_param(params, "lq"),
             conn.assigns.scrivener
           ) do
      render(conn, "index.html",
        title: "Admin - Artist Links",
        artist_links: artist_links,
        changeset: changeset
      )
    end
  end
end
