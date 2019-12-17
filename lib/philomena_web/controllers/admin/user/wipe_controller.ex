defmodule PhilomenaWeb.Admin.User.WipeController do
  use PhilomenaWeb, :controller

  alias Philomena.UserWipe
  alias Philomena.Users.User

  plug :verify_authorized
  plug :load_resource, model: User, id_name: "user_id", id_field: "slug", persisted: true

  def create(conn, _params) do
    spawn fn ->
      UserWipe.perform(conn.assigns.user)
    end

    conn
    |> put_flash(:info, "PII wipe started, please verify and then deactivate the account as necessary.")
    |> redirect(to: Routes.profile_path(conn, :show, conn.assigns.user))
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :index, User) do
      true   -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
