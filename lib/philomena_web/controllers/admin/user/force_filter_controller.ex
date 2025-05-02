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
    |> moderation_log(details: &log_details/2, data: user)
    |> redirect(to: ~p"/profiles/#{user}")
  end

  def delete(conn, _params) do
    {:ok, user} = Users.unforce_filter(conn.assigns.user)

    conn
    |> put_flash(:info, "Forced filter was removed.")
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
        :create -> "Forced filter #{user.forced_filter_id} for #{user.name}"
        :delete -> "Removed forced filter for #{user.name}"
      end

    %{body: body, subject_path: ~p"/profiles/#{user}"}
  end
end
