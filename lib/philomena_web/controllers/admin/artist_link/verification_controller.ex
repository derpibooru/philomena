defmodule PhilomenaWeb.Admin.ArtistLink.VerificationController do
  use PhilomenaWeb, :controller

  alias Philomena.ArtistLinks

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"artist_link_id" => id}) do
    with {:ok, _artist_link} <-
           ArtistLinks.create_artist_link_verification(conn.assigns.actor, id) do
      conn
      |> put_flash(:info, "Artist link successfully verified.")
      |> redirect(to: ~p"/admin/artist_links")
    end
  end
end
