defmodule PhilomenaWeb.Registration.DeactivateController do
  use PhilomenaWeb, :controller

  alias Philomena.Users
  alias Philomena.UserWipe

  plug PhilomenaWeb.FilterBannedUsersPlug

  def new(conn, _params) do
    changeset = Users.change_user(conn.assigns.current_user)
    render(conn, "new.html", title: "Deactivate Your Account", changeset: changeset)
  end

  def create(conn, _params) do
    user = conn.assigns.current_user

    {:ok, user} = Users.deactivate_user(user, user)

    spawn(fn ->
      UserWipe.perform(user)
    end)

    conn
    |> put_flash(:info, "Your account has been deactivated, and your PII will be removed from the database shortly.")
    |> redirect(to: "/")
  end

end
