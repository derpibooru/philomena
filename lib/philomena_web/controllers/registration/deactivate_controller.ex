defmodule PhilomenaWeb.Registration.DeactivateController do
  use PhilomenaWeb, :controller

  alias Philomena.Users

  plug PhilomenaWeb.FilterBannedUsersPlug

  def edit(conn, _params) do
    changeset = Users.change_user(conn.assigns.current_user)
    render(conn, "edit.html", title: "Deactivate Your Account", changeset: changeset)
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Nothing happened")
    |> redirect(to: "/")
  end

end
