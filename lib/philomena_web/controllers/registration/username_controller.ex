defmodule PhilomenaWeb.Registration.UsernameController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.Repo

  plug PhilomenaWeb.FilterBannedUsersPlug

  def edit(conn, _params) do
    changeset = Pow.Plug.change_user(conn)

    render(conn, "edit.html",
      title: "Editing Username",
      changeset: changeset
    )
  end

  def update(conn, %{"user" => user_params}) do
    user = Pow.Plug.current_user(conn)

    user
    |> User.username_changeset(user_params)
    |> Repo.update
    |> case do
      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
      {:ok, user} ->
        conn
        |> put_flash(:info, "Username successfully updated.")
        |> redirect(to: Routes.profile_path(conn, :show, user))
    end
  end
end
