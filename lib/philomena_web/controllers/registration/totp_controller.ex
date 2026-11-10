defmodule PhilomenaWeb.Registration.TotpController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.UserAuth
  alias Philomena.Users.User
  alias Philomena.Users

  def edit(conn, _params) do
    user = conn.assigns.current_user

    case user.encrypted_otp_secret do
      nil ->
        {:ok, _user} = Users.edit_totp(user)

        # Redirect to have the conn pick up the changes
        redirect(conn, to: ~p"/registrations/totp/edit")

      _ ->
        changeset = Users.totp_changeset(user)
        secret = User.totp_secret(user)
        qrcode = User.totp_qrcode(user)

        render(conn, "edit.html",
          title: "Two Factor Authentication",
          changeset: changeset,
          totp_secret: secret,
          totp_qrcode: qrcode
        )
    end
  end

  def update(conn, %{"user" => %{"current_password" => _password}} = params) do
    user = conn.assigns.current_user

    case Users.update_totp(user, params) do
      {:error, changeset} ->
        render_edit(conn, user, changeset)

      {:ok, user, backup_codes} ->
        conn
        |> put_flash(:totp_backup_codes, backup_codes)
        |> put_session(:user_return_to, ~p"/registrations/totp/edit")
        |> UserAuth.totp_auth_user(user, %{})
    end
  end

  def update(conn, _params), do: redirect(conn, to: ~p"/registrations/totp/edit")

  # `edit` generates the secret; without one there is no QR code to re-render.
  defp render_edit(conn, %{encrypted_otp_secret: nil}, _changeset),
    do: redirect(conn, to: ~p"/registrations/totp/edit")

  defp render_edit(conn, user, changeset) do
    render(conn, "edit.html",
      changeset: changeset,
      totp_secret: User.totp_secret(user),
      totp_qrcode: User.totp_qrcode(user)
    )
  end
end
