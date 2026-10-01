defmodule PhilomenaWeb.SessionController do
  use PhilomenaWeb, :controller

  alias Philomena.Users
  alias PhilomenaWeb.UserAuth
  alias PhilomenaWeb.CompromisedPasswordCheckPlug

  plug PhilomenaWeb.CaptchaPlug when action in [:new, :create]
  plug PhilomenaWeb.CheckCaptchaPlug when action in [:create]

  def new(conn, _params) do
    render(conn, "new.html", error_message: nil)
  end

  def create(conn, %{"user" => user_params}) do
    %{"email" => email, "password" => password} = user_params

    user =
      Users.get_user_by_email_and_password(
        email,
        password,
        &url(~p"/unlocks/#{&1}")
      )

    cond do
      not is_nil(user) and CompromisedPasswordCheckPlug.password_compromised?(password) ->
        Users.delete_user_sessions(user)

        conn
        |> put_flash(
          :error,
          "We've detected that the password you entered has been compromised during a data breach of another website. Please reset your password before signing in again."
        )
        |> redirect(to: ~p"/passwords/new")

      not is_nil(user) and is_nil(user.confirmed_at) ->
        render(
          conn,
          "new.html",
          error_message: "You must confirm your account before logging in."
        )

      not is_nil(user) ->
        conn
        |> put_flash(:info, "Successfully logged in.")
        |> UserAuth.log_in_user(user, user_params)

      true ->
        render(
          conn,
          "new.html",
          error_message:
            "Invalid email or password. If you're seeing this more than usual, your account may be locked."
        )
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
