defmodule PhilomenaWeb.Registration.DeactivateController do
  use PhilomenaWeb, :controller

  alias Philomena.Users

  plug PhilomenaWeb.FilterBannedUsersPlug

  def new(conn, _params) do
    changeset = Users.change_user(conn.assigns.current_user)
    render(conn, "new.html", title: "Deactivate Your Account", changeset: changeset)
  end

  def create(conn, _params) do
    conn
    |> put_flash(:info, "Nothing happened")
    |> redirect(to: "/")
  end

end
