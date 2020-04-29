defmodule PhilomenaWeb.Registration.UsernameController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.Users
  alias Philomena.Repo

  plug PhilomenaWeb.FilterBannedUsersPlug
  plug :verify_authorized

  def edit(conn, _params) do
    changeset = Pow.Plug.change_user(conn)

    render(conn, "edit.html",
      title: "Editing Username",
      changeset: changeset
    )
  end

  def update(conn, %{"user" => user_params}) do
    user = Pow.Plug.current_user(conn)

    case Users.update_username(user,user_params) do
      {:error, %{account: changeset}} ->
        render(conn, "edit.html", changeset: changeset)
      {:ok, %{account: user}} ->
        conn
        |> put_flash(:info, "Username successfully updated.")
        |> redirect(to: Routes.profile_path(conn, :show, user))
    end
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :change_username, Pow.Plug.current_user(conn)) do
      true -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
