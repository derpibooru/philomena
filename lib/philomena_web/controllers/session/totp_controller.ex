defmodule PhilomenaWeb.Session.TotpController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.LayoutView
  alias PhilomenaWeb.UserAuth
  alias Philomena.Users

  def new(conn, _params) do
    changeset = Users.totp_changeset(conn.assigns.current_user)

    render(conn, "new.html", layout: {LayoutView, "two_factor.html"}, changeset: changeset)
  end

  def create(conn, %{"user" => user_params} = params) when is_map(user_params) do
    case Users.create_session_totp(conn.assigns.current_user, params) do
      {:ok, user} ->
        UserAuth.totp_auth_user(conn, user, user_params)

      {:error, _changeset} ->
        invalid_token(conn)
    end
  end

  def create(conn, _params), do: invalid_token(conn)

  defp invalid_token(conn) do
    conn
    |> put_flash(:error, "Invalid TOTP token entered. Please sign in again.")
    |> UserAuth.log_out_user()
  end
end
