defmodule PhilomenaWeb.ReactivationController do
  use PhilomenaWeb, :controller
  alias Philomena.Users

  def show(conn, %{"id" => token}) do
    render(conn, "show.html", title: "Reactivate Your Account", token: token)
  end

  def update(conn, %{"id" => token}) do
    Users.create_reactivation(token)

    conn
    |> put_flash(:info, "If the token provided was valid, your account has been reactivated.")
    |> redirect(to: "/")
  end
end
