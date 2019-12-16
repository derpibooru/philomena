defmodule PhilomenaWeb.Profile.UserLinkController do
  use PhilomenaWeb, :controller

  alias Philomena.UserLinks.UserLink
  alias Philomena.UserLinks
  alias Philomena.Users.User
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.FilterBannedUsersPlug when action in [:new, :create]
  plug :load_and_authorize_resource, model: UserLink, only: [:show, :edit, :update], preload: [:user, :tag, :contacted_by_user]

  plug PhilomenaWeb.CanaryMapPlug,
    index: :create_links,
    new: :create_links,
    create: :create_links,
    show: :create_links,
    edit: :edit_links,
    update: :edit_links

  plug :load_and_authorize_resource, model: User, id_field: "slug", id_name: "profile_id", persisted: true

  def index(conn, _params) do
    user = conn.assigns.current_user
    user_links =
      UserLink
      |> where(user_id: ^user.id)
      |> Repo.all()

    render(conn, "index.html", title: "User Links", user_links: user_links)
  end

  def new(conn, _params) do
    changeset = UserLinks.change_user_link(%UserLink{})
    render(conn, "new.html", title: "New User Link", changeset: changeset)
  end

  def create(conn, %{"user_link" => user_link_params}) do
    case UserLinks.create_user_link(conn.assigns.user, user_link_params) do
      {:ok, user_link} ->
        conn
        |> put_flash(:info, "Link submitted! Please put '#{user_link.verification_code}' on your linked webpage now.")
        |> redirect(to: Routes.profile_user_link_path(conn, :show, conn.assigns.user_link, user_link))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, _params) do
    user_link = conn.assigns.user_link
    render(conn, "show.html", title: "Showing User Link", user_link: user_link)
  end

  def edit(conn, _params) do
    changeset = UserLinks.change_user_link(conn.assigns.user_link)

    render(conn, "edit.html", title: "Editing User Link", changeset: changeset)
  end

  def update(conn, %{"user_link" => user_link_params}) do
    case UserLinks.update_user_link(conn.assigns.user_link, user_link_params) do
      {:ok, user_link} ->
        conn
        |> put_flash(:info, "Link successfully updated.")
        |> redirect(to: Routes.profile_user_link_path(conn, :show, conn.assigns.user, user_link))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end
end
