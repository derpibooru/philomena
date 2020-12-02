defmodule PhilomenaWeb.Profile.ArtistLinkController do
  use PhilomenaWeb, :controller

  alias Philomena.ArtistLinks.ArtistLink
  alias Philomena.ArtistLinks
  alias Philomena.Users.User
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.FilterBannedUsersPlug when action in [:new, :create]

  plug :load_and_authorize_resource,
    model: ArtistLink,
    only: [:show, :edit, :update],
    preload: [:user, :tag, :contacted_by_user]

  plug PhilomenaWeb.CanaryMapPlug,
    index: :create_links,
    new: :create_links,
    create: :create_links,
    show: :create_links,
    edit: :edit_links,
    update: :edit_links

  plug :load_and_authorize_resource,
    model: User,
    id_field: "slug",
    id_name: "profile_id",
    persisted: true

  def index(conn, _params) do
    user = conn.assigns.current_user

    artist_links =
      ArtistLink
      |> where(user_id: ^user.id)
      |> Repo.all()

    render(conn, "index.html", title: "Artist Links", artist_links: artist_links)
  end

  def new(conn, _params) do
    changeset = ArtistLinks.change_artist_link(%ArtistLink{})
    render(conn, "new.html", title: "New Artist Link", changeset: changeset)
  end

  def create(conn, %{"artist_link" => artist_link_params}) do
    case ArtistLinks.create_artist_link(conn.assigns.user, artist_link_params) do
      {:ok, artist_link} ->
        conn
        |> put_flash(
          :info,
          "Link submitted! Please put '#{artist_link.verification_code}' on your linked webpage now."
        )
        |> redirect(
          to: Routes.profile_artist_link_path(conn, :show, conn.assigns.user, artist_link)
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, _params) do
    artist_link = conn.assigns.artist_link
    render(conn, "show.html", title: "Showing Artist Link", artist_link: artist_link)
  end

  def edit(conn, _params) do
    changeset = ArtistLinks.change_artist_link(conn.assigns.artist_link)

    render(conn, "edit.html", title: "Editing Artist Link", changeset: changeset)
  end

  def update(conn, %{"artist_link" => artist_link_params}) do
    case ArtistLinks.update_artist_link(conn.assigns.artist_link, artist_link_params) do
      {:ok, artist_link} ->
        conn
        |> put_flash(:info, "Link successfully updated.")
        |> redirect(
          to: Routes.profile_artist_link_path(conn, :show, conn.assigns.user, artist_link)
        )

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end
end
