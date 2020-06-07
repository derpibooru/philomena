defmodule PhilomenaWeb.Admin.User.ForceFilterController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.Users

  plug :verify_authorized
  plug :load_resource, model: User, id_name: "user_id", id_field: "slug", persisted: true

  def new(conn, _params) do
    changeset = Users.change_user(conn.assigns.user)

    render(conn, "new.html", changeset: changeset, title: "Forcing filter for user")
  end

  def create(conn, %{"user" => user_params}) do
    {:ok, user} = Users.force_filter(conn.assigns.user, user_params)

    conn
    |> put_flash(:info, "Filter was forced.")
    |> redirect(to: Routes.profile_path(conn, :show, user))
  end

  def delete(conn, _params) do
    {:ok, user} = Users.unforce_filter(conn.assigns.user)

    conn
    |> put_flash(:info, "Forced filter was removed.")
    |> redirect(to: Routes.profile_path(conn, :show, user))
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :index, User) do
      true -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
