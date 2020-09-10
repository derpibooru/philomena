defmodule PhilomenaWeb.AvatarController do
  use PhilomenaWeb, :controller

  alias Philomena.Users

  plug PhilomenaWeb.FilterBannedUsersPlug

  plug PhilomenaWeb.ScraperPlug,
       [params_name: "user", params_key: "avatar"] when action in [:update]

  def edit(conn, _params) do
    changeset = Users.change_user(conn.assigns.current_user)
    render(conn, "edit.html", title: "Editing Avatar", changeset: changeset)
  end

  def update(conn, %{"user" => user_params}) do
    case Users.update_avatar(conn.assigns.current_user, user_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Successfully updated avatar.")
        |> redirect(to: Routes.avatar_path(conn, :edit))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  def delete(conn, _params) do
    {:ok, _user} = Users.remove_avatar(conn.assigns.current_user)

    conn
    |> put_flash(:info, "Successfully removed avatar.")
    |> redirect(to: Routes.avatar_path(conn, :edit))
  end
end
