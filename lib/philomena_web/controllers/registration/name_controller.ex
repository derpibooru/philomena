defmodule PhilomenaWeb.Registration.NameController do
  use PhilomenaWeb, :controller

  alias Philomena.Users

  plug PhilomenaWeb.FilterBannedUsersPlug
  plug :verify_authorized
  plug PhilomenaWeb.NameLengthLimiterPlug when action in [:update]
  plug PhilomenaWeb.NotableNamePlug when action in [:update]

  def edit(conn, _params) do
    changeset = Users.change_user(conn.assigns.current_user)

    render(conn, "edit.html", title: "Editing Name", changeset: changeset)
  end

  def update(conn, %{"user" => user_params}) do
    case Users.update_name(conn.assigns.current_user, user_params) do
      {:ok, %{account: user}} ->
        conn
        |> put_flash(:info, "Name successfully updated.")
        |> redirect(to: Routes.profile_path(conn, :show, user))

      {:error, %{account: changeset}} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :change_username, conn.assigns.current_user) do
      true -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
