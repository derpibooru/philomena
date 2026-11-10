defmodule PhilomenaWeb.RegistrationController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.UserAuth
  alias Philomena.Users
  alias Philomena.Users.User

  action_fallback PhilomenaWeb.FallbackController

  plug PhilomenaWeb.CaptchaPlug when action in [:new, :create]
  plug PhilomenaWeb.CheckCaptchaPlug when action in [:create]

  def new(conn, _params) do
    with {:ok, changeset} <- Users.new_registration(conn.assigns.actor, %User{}) do
      render(conn, "new.html", changeset: changeset)
    end
  end

  def create(conn, %{"user" => user_params}) do
    case Users.create_registration(conn.assigns.actor, user_params) do
      {:ok, user} ->
        UserAuth.update_usages(conn, user)

        {:ok, _} =
          Users.deliver_user_confirmation_instructions(
            user,
            &url(~p"/confirmations/#{&1}")
          )

        conn
        |> put_flash(
          :info,
          "Account created successfully. Check your email for confirmation instructions."
        )
        |> redirect(to: "/")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)

      error ->
        error
    end
  end

  def edit(conn, _params) do
    user = conn.assigns.current_user

    render(
      conn,
      "edit.html",
      title: "Account Settings",
      email_changeset: Users.change_user_email(user),
      password_changeset: Users.edit_password(user)
    )
  end
end
