defmodule PhilomenaWeb.UserLinkController do
  use PhilomenaWeb, :controller

  alias Philomena.UserLinks
  alias Philomena.UserLinks.UserLink
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.FilterBannedUsersPlug when action in [:new, :create]
  plug :load_and_authorize_resource, model: UserLink, only: [:show], preload: [:user, :tag, :contacted_by_user]

  def index(conn, _params) do
    user = conn.assigns.current_user
    user_links =
      UserLink
      |> where(user_id: ^user.id)
      |> Repo.all()

    render(conn, "index.html", user_links: user_links)
  end

  def new(conn, _params) do
    changeset = UserLinks.change_user_link(%UserLink{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user_link" => user_link_params}) do
    user = conn.assigns.current_user

    case UserLinks.create_user_link(user, user_link_params) do
      {:ok, user_link} ->
        conn
        |> put_flash(:info, "Link submitted! Please put '#{user_link.verification_code}' on your linked webpage now.")
        |> redirect(to: Routes.user_link_path(conn, :show, user_link))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, _params) do
    user_link = conn.assigns.user_link
    render(conn, "show.html", user_link: user_link)
  end
end
