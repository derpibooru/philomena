defmodule PhilomenaWeb.Registration.EmailController do
  use PhilomenaWeb, :controller

  alias Philomena.Users

  def create(conn, %{"current_password" => password, "user" => user_params}) do
    user = conn.assigns.current_user

    case Users.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Users.deliver_update_email_instructions(
          applied_user,
          user.email,
          &Routes.registration_email_url(conn, :show, &1)
        )

        conn
        |> put_flash(
          :info,
          "A link to confirm your email change has been sent to the new address."
        )
        |> redirect(to: Routes.registration_path(conn, :edit))

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Failed to update email.")
        |> redirect(to: Routes.registration_path(conn, :edit))
    end
  end

  def show(conn, %{"id" => token}) do
    case Users.update_user_email(conn.assigns.current_user, token) do
      :ok ->
        conn
        |> put_flash(:info, "Email changed successfully.")
        |> redirect(to: Routes.registration_path(conn, :edit))

      :error ->
        conn
        |> put_flash(:error, "Email change link is invalid or it has expired.")
        |> redirect(to: Routes.registration_path(conn, :edit))
    end
  end
end
