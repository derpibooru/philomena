defmodule PhilomenaWeb.Profile.ArtistLinkController do
  use PhilomenaWeb, :controller

  alias Philomena.ArtistLinks

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, %{"profile_id" => slug}) do
    with {:ok, {user, artist_links}} <-
           ArtistLinks.list_artist_links(conn.assigns.actor, slug) do
      render(conn, "index.html", title: "Artist Links", user: user, artist_links: artist_links)
    end
  end

  def new(conn, %{"profile_id" => slug}) do
    with {:ok, {user, changeset}} <-
           ArtistLinks.new_artist_link(conn.assigns.actor, slug) do
      render(conn, "new.html", title: "New Artist Link", user: user, changeset: changeset)
    end
  end

  def create(conn, %{"profile_id" => slug, "artist_link" => artist_link_params}) do
    case ArtistLinks.create_artist_link(conn.assigns.actor, slug, artist_link_params) do
      {:ok, {user, artist_link}} ->
        conn
        |> put_flash(
          :info,
          "Link submitted! Please put '#{artist_link.verification_code}' on your linked webpage now."
        )
        |> redirect(to: ~p"/profiles/#{user}/artist_links/#{artist_link}")

      {:error, {user, changeset}} ->
        render(conn, "new.html", user: user, changeset: changeset)

      {:error, _} = error ->
        error
    end
  end

  def show(conn, %{"profile_id" => slug, "id" => id}) do
    with {:ok, {user, artist_link}} <-
           ArtistLinks.show_artist_link(conn.assigns.actor, slug, id) do
      render(conn, "show.html",
        title: "Showing Artist Link",
        user: user,
        artist_link: artist_link
      )
    end
  end

  def edit(conn, %{"profile_id" => slug, "id" => id}) do
    with {:ok, {artist_link, changeset}} <-
           ArtistLinks.edit_artist_link(conn.assigns.actor, slug, id) do
      render(conn, "edit.html",
        title: "Editing Artist Link",
        artist_link: artist_link,
        changeset: changeset
      )
    end
  end

  def update(conn, %{"profile_id" => slug, "id" => id, "artist_link" => artist_link_params}) do
    case ArtistLinks.update_artist_link(conn.assigns.actor, slug, id, artist_link_params) do
      {:ok, {user, artist_link}} ->
        conn
        |> put_flash(:info, "Link successfully updated.")
        |> redirect(to: ~p"/profiles/#{user}/artist_links/#{artist_link}")

      {:error, {artist_link, changeset}} ->
        render(conn, "edit.html", artist_link: artist_link, changeset: changeset)

      {:error, _} = error ->
        error
    end
  end
end
