defmodule PhilomenaWeb.Admin.ArtistLink.VerificationController do
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
    {:ok, _} = ArtistLinks.verify_artist_link(conn.assigns.artist_link, conn.assigns.current_user)

    conn
    |> put_flash(:info, "Artist link successfully verified.")
    |> redirect(to: Routes.admin_artist_link_path(conn, :index))
  end
end
