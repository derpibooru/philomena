defmodule PhilomenaWeb.SettingController do
  require Logger
  use PhilomenaWeb, :controller

  alias Philomena.Users
  alias Philomena.Users.User
  alias Philomena.Schema.TagList
  alias Plug.Conn

  def edit(conn, _params) do
    changeset =
      (conn.assigns.current_user || %User{})
      |> assign_theme()
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
        |> redirect(to: ~p"/settings/edit")

      {:error, changeset} ->
        conn
        |> put_flash(:error, "Your settings could not be saved!")
        |> render("edit.html", changeset: changeset)
    end
  end

  defp update_local_settings(conn, user_params) do
    conn
    |> set_bool_cookie(user_params, "hidpi", "hidpi")
    |> set_bool_cookie(user_params, "webm", "webm")
    |> set_bool_cookie(user_params, "serve_webm", "serve_webm")
    |> set_bool_cookie(user_params, "unmute_videos", "unmute_videos")
    |> set_bool_cookie(user_params, "chan_nsfw", "chan_nsfw")
    |> set_bool_cookie(user_params, "hide_staff_tools", "hide_staff_tools")
    |> set_bool_cookie(user_params, "hide_uploader", "hide_uploader")
    |> set_bool_cookie(user_params, "hide_score", "hide_score")
    |> set_bool_cookie(user_params, "unfilter_tag_suggestions", "unfilter_tag_suggestions")
    |> set_bool_cookie(user_params, "enable_search_ac", "enable_search_ac")
    |> set_bool_cookie(
      user_params,
      "autocomplete_search_history_hidden",
      "autocomplete_search_history_hidden"
    )
    |> set_cookie(
      "autocomplete_search_history_max_suggestions_when_typing",
      user_params["autocomplete_search_history_max_suggestions_when_typing"]
    )
  end

  defp set_bool_cookie(conn, params, param_name, cookie_name) do
    set_cookie(conn, cookie_name, to_string(params[param_name] == "true"))
  end

  defp set_cookie(conn, _, nil), do: conn

  defp set_cookie(conn, cookie_name, value) do
    # JS wants access; max-age is set to 25 years from now
    Conn.put_resp_cookie(conn, cookie_name, value,
      max_age: 788_923_800,
      http_only: false,
      extra: "SameSite=Lax"
    )
  end

  defp assign_theme(%{theme: theme} = user) do
    [theme_name, theme_color] = String.split(theme, "-")

    user
    |> Map.put(:theme_name, theme_name)
    |> Map.put(:theme_color, theme_color)
  end

  defp assign_theme(_), do: assign_theme(%{theme: "dark-blue"})

  defp determine_theme(%{"theme_name" => name, "theme_color" => color} = attrs)
       when name != nil and color != nil,
       do: Map.put(attrs, "theme", "#{name}-#{color}")

  defp determine_theme(attrs), do: Map.put(attrs, "theme", "dark-blue")

  defp maybe_update_user(conn, nil, _user_params), do: {:ok, conn}

  defp maybe_update_user(conn, user, user_params) do
    case Users.update_settings(user, determine_theme(user_params)) do
      {:ok, _user} ->
        {:ok, conn}

      error ->
        error
    end
  end
end
