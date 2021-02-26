defmodule PhilomenaWeb.RegistrationController do
  use PhilomenaWeb, :controller

  alias Philomena.Users
  alias Philomena.Users.User

  plug PhilomenaWeb.CaptchaPlug when action in [:new, :create]
  plug PhilomenaWeb.CheckCaptchaPlug when action in [:create]
  plug PhilomenaWeb.CompromisedPasswordCheckPlug when action in [:create]
  plug :assign_email_and_password_changesets when action in [:edit]

  def new(conn, _params) do
    changeset = Users.change_user_registration(%User{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case Users.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Users.deliver_user_confirmation_instructions(
            user,
            &Routes.confirmation_url(conn, :show, &1)
          )

        conn
        |> put_flash(
          :info,
          "Account created successfully. Check your email for confirmation instructions."
        )
        |> redirect(to: "/")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def edit(conn, _params) do
    render(conn, "edit.html", title: "Account Settings")
  end

  defp assign_email_and_password_changesets(conn, _opts) do
    user = conn.assigns.current_user

    conn
    |> assign(:email_changeset, Users.change_user_email(user))
    |> assign(:password_changeset, Users.change_user_password(user))
  end
end
