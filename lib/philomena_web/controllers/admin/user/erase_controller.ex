defmodule PhilomenaWeb.Admin.User.EraseController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.Users

  plug :verify_authorized

  plug :load_resource,
    model: User,
    id_name: "user_id",
    id_field: "slug",
    persisted: true,
    preload: [:roles]

  plug :prevent_deleting_privileged_users
  plug :prevent_deleting_verified_users
  plug :prevent_deleting_old_users

  def new(conn, _params) do
    render(conn, "new.html", title: "Erase user")
  end

  def create(conn, _params) do
    {:ok, user} = Users.erase_user(conn.assigns.user, conn.assigns.current_user)

    conn
    |> put_flash(:info, "User erase started")
    |> redirect(to: ~p"/profiles/#{user}")
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :index, User) do
      true -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp prevent_deleting_privileged_users(conn, _opts) do
    if conn.assigns.user.role != "user" do
      conn
      |> put_flash(:error, "Cannot erase a privileged user")
      |> redirect(to: ~p"/profiles/#{conn.assigns.user}")
      |> Plug.Conn.halt()
    else
      conn
    end
  end

  defp prevent_deleting_verified_users(conn, _opts) do
    if conn.assigns.user.verified do
      conn
      |> put_flash(:error, "Cannot erase a verified user")
      |> redirect(to: ~p"/profiles/#{conn.assigns.user}")
      |> Plug.Conn.halt()
    else
      conn
    end
  end

  defp prevent_deleting_old_users(conn, _opts) do
    now = DateTime.utc_now(:second)
    two_weeks = 1_209_600

    if DateTime.compare(now, DateTime.add(conn.assigns.user.created_at, two_weeks)) == :gt do
      conn
      |> put_flash(:error, "Cannot erase a user older than two weeks")
      |> redirect(to: ~p"/profiles/#{conn.assigns.user}")
      |> Plug.Conn.halt()
    else
      conn
    end
  end
end
