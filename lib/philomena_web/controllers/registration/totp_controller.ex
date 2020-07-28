defmodule PhilomenaWeb.Registration.TotpController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.UserAuth
  alias Philomena.Users.User
  alias Philomena.Users
  alias Philomena.Repo

  def edit(conn, _params) do
    user = conn.assigns.current_user

    case user.encrypted_otp_secret do
      nil ->
        user
        |> User.create_totp_secret_changeset()
        |> Repo.update()

        # Redirect to have the conn pick up the changes
        redirect(conn, to: Routes.registration_totp_path(conn, :edit))

      _ ->
        changeset = Users.change_user(user)
        secret = User.totp_secret(user)
        qrcode = User.totp_qrcode(user)

        render(conn, "edit.html",
          title: "Two-Factor Authentication",
          changeset: changeset,
          totp_secret: secret,
          totp_qrcode: qrcode
        )
    end
  end

  def update(conn, params) do
    backup_codes = User.random_backup_codes()
    user = conn.assigns.current_user

    user
    |> User.totp_changeset(params, backup_codes)
    |> Repo.update()
    |> case do
      {:error, changeset} ->
        secret = User.totp_secret(user)
        qrcode = User.totp_qrcode(user)
        render(conn, "edit.html", changeset: changeset, totp_secret: secret, totp_qrcode: qrcode)

      {:ok, user} ->
        conn
        |> UserAuth.totp_auth_user(user, %{})
        |> put_flash(:totp_backup_codes, backup_codes)
        |> redirect(to: Routes.registration_totp_path(conn, :edit))
    end
  end
end
