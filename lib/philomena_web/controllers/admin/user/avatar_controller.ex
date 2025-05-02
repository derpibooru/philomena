defmodule PhilomenaWeb.Admin.User.AvatarController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.Users

  plug :verify_authorized
  plug :load_resource, model: User, id_name: "user_id", id_field: "slug", persisted: true

  def delete(conn, _params) do
    {:ok, user} = Users.remove_avatar(conn.assigns.user)

    conn
    |> put_flash(:info, "Successfully removed avatar.")
    |> moderation_log(details: &log_details/2, data: user)
    |> redirect(to: ~p"/admin/users/#{conn.assigns.user}/edit")
  end

  defp verify_authorized(conn, _opts) do
    if Canada.Can.can?(conn.assigns.current_user, :index, User) do
      conn
    else
      PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp log_details(_action, user) do
    %{body: "Removed avatar for #{user.name}", subject_path: ~p"/profiles/#{user}"}
  end
end
