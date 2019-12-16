defmodule PhilomenaWeb.Registration.TotpController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.Repo

  def edit(conn, _params) do
    user = conn.assigns.current_user

    case user.encrypted_otp_secret do
      nil ->
        user
        |> User.create_totp_secret_changeset()
        |> Repo.update()

        # Redirect to have Pow pick up the changes
        redirect(conn, to: Routes.registration_totp_path(conn, :edit))

      _ ->
        changeset = Pow.Plug.change_user(conn)
        secret = User.totp_secret(user)
        qrcode = User.totp_qrcode(user)
        render(conn, "edit.html", title: "Two-Factor Authentication", changeset: changeset, totp_secret: secret, totp_qrcode: qrcode)
    end
  end

  def update(conn, params) do
    backup_codes = User.random_backup_codes()
    user = Pow.Plug.current_user(conn)

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
        |> PhilomenaWeb.TotpPlug.update_valid_totp_at_for_session(user)
        |> put_flash(:totp_backup_codes, backup_codes)
        |> redirect(to: Routes.registration_totp_path(conn, :edit))
    end
  end
end
