defmodule PhilomenaWeb.UnlockController do
  use PhilomenaWeb, :controller

  alias Philomena.Users

  plug PhilomenaWeb.CaptchaPlug
  plug PhilomenaWeb.CheckCaptchaPlug when action in [:create]

  def new(conn, _params) do
    render(conn, "new.html")
  end

  def create(conn, %{"user" => %{"email" => email}}) do
    if user = Users.get_user_by_email(email) do
      Users.deliver_user_unlock_instructions(
        user,
        &Routes.unlock_url(conn, :show, &1)
      )
    end

    # Regardless of the outcome, show an impartial success/error message.
    conn
    |> put_flash(
      :info,
      "If your email is in our system and your account has been locked, " <>
        "you will receive an email with instructions shortly."
    )
    |> redirect(to: "/")
  end

  # Do not log in the user after unlocking to avoid a
  # leaked token giving the user access to the account.
  def show(conn, %{"id" => token}) do
    case Users.unlock_user_by_token(token) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Account unlocked successfully. You may now log in.")
        |> redirect(to: "/")

      :error ->
        conn
        |> put_flash(:error, "Unlock link is invalid or it has expired.")
        |> redirect(to: "/")
    end
  end
end
