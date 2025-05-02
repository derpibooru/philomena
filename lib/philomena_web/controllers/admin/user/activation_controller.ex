defmodule PhilomenaWeb.Admin.User.ActivationController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.Users

  plug :verify_authorized
  plug :load_resource, model: User, id_name: "user_id", id_field: "slug", persisted: true

  def create(conn, _params) do
    {:ok, user} = Users.reactivate_user(conn.assigns.user)

    conn
    |> put_flash(:info, "User was reactivated.")
    |> moderation_log(details: &log_details/2, data: user)
    |> redirect(to: ~p"/profiles/#{user}")
  end

  def delete(conn, _params) do
    {:ok, user} = Users.deactivate_user(conn.assigns.current_user, conn.assigns.user)

    conn
    |> put_flash(:info, "User was deactivated.")
    |> moderation_log(details: &log_details/2, data: user)
    |> redirect(to: ~p"/profiles/#{user}")
  end

  defp verify_authorized(conn, _opts) do
    if Canada.Can.can?(conn.assigns.current_user, :index, User) do
      conn
    else
      PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp log_details(action, user) do
    body =
      case action do
        :create -> "Reactivated #{user.name}"
        :delete -> "Deactivated #{user.name}"
      end

    %{body: body, subject_path: ~p"/profiles/#{user}"}
  end
end
