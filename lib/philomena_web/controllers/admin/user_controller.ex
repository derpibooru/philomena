defmodule PhilomenaWeb.Admin.UserController do
  use PhilomenaWeb, :controller

  alias Philomena.Roles.Role
  alias Philomena.Users.User
  alias Philomena.Users
  alias Philomena.Repo
  import Ecto.Query

  plug :verify_authorized

  plug :load_and_authorize_resource,
    model: User,
    only: [:edit, :update],
    id_field: "slug",
    preload: [:roles]

  plug :load_roles when action in [:edit]

  def index(conn, %{"q" => q}) do
    User
    |> where([u], u.email == ^q or ilike(u.name, ^"%#{q}%"))
    |> load_users(conn)
  end

  def index(conn, %{"twofactor" => _twofactor}) do
    User
    |> where([u], u.otp_required_for_login == true)
    |> load_users(conn)
  end

  def index(conn, %{"staff" => _staff}) do
    User
    |> where([u], u.role != "user")
    |> load_users(conn)
  end

  def index(conn, _params) do
    load_users(User, conn)
  end

  defp load_users(queryable, conn) do
    users =
      queryable
      |> order_by(desc: :id)
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, "index.html",
      title: "Admin - Users",
      layout_class: "layout--medium",
      users: users
    )
  end

  def edit(conn, _params) do
    changeset = Users.change_user(conn.assigns.user)
    render(conn, "edit.html", title: "Editing User", changeset: changeset)
  end

  def update(conn, %{"user" => user_params}) do
    case Users.update_user(conn.assigns.user, user_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "User successfully updated.")
        |> redirect(to: Routes.profile_path(conn, :show, conn.assigns.user))

      {:error, %{user: changeset}} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :index, User) do
      true -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp load_roles(conn, _opts) do
    assign(conn, :roles, Repo.all(Role))
  end
end
