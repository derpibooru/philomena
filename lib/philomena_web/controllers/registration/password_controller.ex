defmodule PhilomenaWeb.Registration.PasswordController do
  use PhilomenaWeb, :controller

  alias Philomena.Users
  alias PhilomenaWeb.UserAuth

  plug PhilomenaWeb.CompromisedPasswordCheckPlug when action in [:update]

  def update(conn, %{"current_password" => password, "user" => user_params}) do
    user = conn.assigns.current_user

    case Users.update_user_password(user, password, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> put_session(:user_return_to, Routes.registration_path(conn, :edit))
        |> UserAuth.log_in_user(user)

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Failed to update password.")
        |> redirect(to: Routes.registration_path(conn, :edit))
    end
  end
end
