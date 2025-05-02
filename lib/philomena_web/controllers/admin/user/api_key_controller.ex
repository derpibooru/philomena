defmodule PhilomenaWeb.Admin.User.ApiKeyController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.Users

  plug :verify_authorized
  plug :load_resource, model: User, id_name: "user_id", id_field: "slug", persisted: true

  def delete(conn, _params) do
    {:ok, user} = Users.reset_api_key(conn.assigns.user)

    conn
    |> put_flash(:info, "API token successfully reset.")
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

  defp log_details(_action, user) do
    %{body: "Reset API key for #{user.name}", subject_path: ~p"/profiles/#{user}"}
  end
end
