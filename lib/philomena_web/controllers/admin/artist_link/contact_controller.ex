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
    {:ok, artist_link} =
      ArtistLinks.contact_artist_link(conn.assigns.artist_link, conn.assigns.current_user)

    conn
    |> put_flash(:info, "Artist successfully marked as contacted.")
    |> moderation_log(details: &log_details/3, data: artist_link)
    |> redirect(to: Routes.admin_artist_link_path(conn, :index))
  end

  defp log_details(conn, _action, artist_link) do
    %{
      body: "Contacted artist #{artist_link.user.name} at #{artist_link.uri}",
      subject_path: Routes.profile_artist_link_path(conn, :show, artist_link.user, artist_link)
    }
  end
end
