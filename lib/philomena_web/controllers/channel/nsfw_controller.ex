defmodule PhilomenaWeb.Channel.NsfwController do
  use PhilomenaWeb, :controller

  alias Plug.Conn

  def create(conn, _params) do
    conn
    |> set_cookie("chan_nsfw", "true")
    |> put_flash(:info, "Successfully updated channel visibility.")
    |> redirect(to: Routes.channel_path(conn, :index))
  end

  def delete(conn, _params) do
    conn
    |> set_cookie("chan_nsfw", "false")
    |> put_flash(:info, "Successfully updated channel visibility.")
    |> redirect(to: Routes.channel_path(conn, :index))
  end

  # Duplicated from setting controller
  defp set_cookie(conn, cookie_name, value) do
    # JS wants access; max-age is set to 25 years from now
    Conn.put_resp_cookie(conn, cookie_name, value,
      max_age: 788_923_800,
      http_only: false,
      extra: "SameSite=Lax"
    )
  end
end
