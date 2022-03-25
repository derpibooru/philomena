defmodule PhilomenaWeb.Admin.User.VerificationController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.Users

  plug :verify_authorized
  plug :load_resource, model: User, id_name: "user_id", id_field: "slug", persisted: true

  def create(conn, _params) do
    {:ok, user} = Users.verify_user(conn.assigns.user)

    conn
    |> put_flash(:info, "User verification granted.")
    |> moderation_log(details: &log_details/3, data: user)
    |> redirect(to: Routes.profile_path(conn, :show, user))
  end

  def delete(conn, _params) do
    {:ok, user} = Users.unverify_user(conn.assigns.user)

    conn
    |> put_flash(:info, "User verification revoked.")
    |> moderation_log(details: &log_details/3, data: user)
    |> redirect(to: Routes.profile_path(conn, :show, user))
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :index, User) do
      true -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp log_details(conn, action, user) do
    body =
      case action do
        :create -> "Granted verification to #{user.name}"
        :delete -> "Revoked verification from #{user.name}"
      end

    %{body: body, subject_path: Routes.profile_path(conn, :show, user)}
  end
end
