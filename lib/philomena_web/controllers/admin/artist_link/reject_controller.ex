defmodule PhilomenaWeb.Admin.ArtistLink.RejectController do
  use PhilomenaWeb, :controller

  alias Philomena.ArtistLinks

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"artist_link_id" => id}) do
    with {:ok, _artist_link} <- ArtistLinks.create_artist_link_reject(conn.assigns.actor, id) do
      conn
      |> put_flash(:info, "Artist link successfully marked as rejected.")
      |> redirect(to: ~p"/admin/artist_links")
    end
  end
end
