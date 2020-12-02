defmodule PhilomenaWeb.Admin.ArtistLink.ContactController do
  use PhilomenaWeb, :controller

  alias Philomena.ArtistLinks.ArtistLink
  alias Philomena.ArtistLinks

  plug PhilomenaWeb.CanaryMapPlug, create: :edit

  plug :load_and_authorize_resource,
    model: ArtistLink,
    id_name: "artist_link_id",
    persisted: true,
    preload: [:user]

  def create(conn, _params) do
    {:ok, _} =
      ArtistLinks.contact_artist_link(conn.assigns.artist_link, conn.assigns.current_user)

    conn
    |> put_flash(:info, "Artist successfully marked as contacted.")
    |> redirect(to: Routes.admin_artist_link_path(conn, :index))
  end
end
