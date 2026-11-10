defmodule PhilomenaWeb.Registration.PasswordController do
  use PhilomenaWeb, :controller

  alias Philomena.Users
  alias PhilomenaWeb.UserAuth

  def update(conn, %{"current_password" => password, "user" => user_params}) do
    user = conn.assigns.current_user

    case Users.update_password(user, password, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> put_session(:user_return_to, ~p"/registrations/edit")
        |> UserAuth.log_in_user(user)

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Failed to update password.")
        |> redirect(to: ~p"/registrations/edit")
    end
  end
end
