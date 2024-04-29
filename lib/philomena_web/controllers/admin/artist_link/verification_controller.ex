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
    {:ok, result} =
      ArtistLinks.verify_artist_link(conn.assigns.artist_link, conn.assigns.current_user)

    conn
    |> put_flash(:info, "Artist link successfully verified.")
    |> moderation_log(details: &log_details/3, data: result.artist_link)
    |> redirect(to: ~p"/admin/artist_links")
  end

  defp log_details(_conn, _action, artist_link) do
    %{
      body: "Verified artist link #{artist_link.uri} created by #{artist_link.user.name}",
      subject_path: ~p"/profiles/#{artist_link.user}/artist_links/#{artist_link}"
    }
  end
end
