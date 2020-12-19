defmodule PhilomenaWeb.SettingController do
  use PhilomenaWeb, :controller

  alias Philomena.Users
  alias Philomena.Users.User
  alias Philomena.Schema.TagList
  alias Plug.Conn

  def edit(conn, _params) do
    changeset =
      (conn.assigns.current_user || %User{})
      |> TagList.assign_tag_list(:watched_tag_ids, :watched_tag_list)
      |> Users.change_user()

    render(conn, "edit.html", title: "Editing Settings", changeset: changeset)
  end

  def update(conn, %{"user" => user_params}) do
    user = conn.assigns.current_user

    conn
    |> update_local_settings(user_params)
    |> maybe_update_user(user, user_params)
    |> case do
      {:ok, conn} ->
        conn
        |> put_flash(:info, "Settings updated successfully.")
        |> redirect(to: Routes.setting_path(conn, :edit))

      {:error, changeset} ->
        conn
        |> put_flash(:error, "Your settings could not be saved!")
        |> render("edit.html", changeset: changeset)
    end
  end

  defp update_local_settings(conn, user_params) do
    conn
    |> set_cookie(user_params, "hidpi", "hidpi")
    |> set_cookie(user_params, "webm", "webm")
    |> set_cookie(user_params, "serve_webm", "serve_webm")
    |> set_cookie(user_params, "chan_nsfw", "chan_nsfw")
    |> set_cookie(user_params, "hide_staff_tools", "hide_staff_tools")
    |> set_cookie(user_params, "hide_uploader", "hide_uploader")
    |> set_cookie(user_params, "hide_score", "hide_score")
  end

  defp set_cookie(conn, params, param_name, cookie_name) do
    # JS wants access; max-age is set to 25 years from now
    Conn.put_resp_cookie(conn, cookie_name, to_string(params[param_name] == "true"),
      max_age: 788_923_800,
      http_only: false,
      extra: "SameSite=Lax"
    )
  end

  defp maybe_update_user(conn, nil, _user_params), do: {:ok, conn}

  defp maybe_update_user(conn, user, user_params) do
    case Users.update_settings(user, user_params) do
      {:ok, _user} ->
        {:ok, conn}

      error ->
        error
    end
  end
end
