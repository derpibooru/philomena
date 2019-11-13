defmodule PhilomenaWeb.Session.TotpController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.Repo

  def new(conn, _params) do
    changeset = Pow.Plug.change_user(conn)

    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, params) do
    conn
    |> Pow.Plug.current_user()
    |> User.consume_totp_token_changeset(params)
    |> Repo.update()
    |> case do
      {:error, _changeset} ->
        conn
        |> Pow.Plug.clear_authenticated_user()
        |> put_flash(:error, "Sorry, invalid TOTP token entered. Please sign in again.")
        |> redirect(to: Routes.pow_session_path(conn, :new))

      {:ok, user} ->
        conn
        |> PhilomenaWeb.Plugs.TotpPlug.update_valid_totp_at_for_session(user)
        |> redirect(to: "/")
    end
  end
end