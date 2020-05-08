defmodule PhilomenaWeb.ReloadUserPlug do
  alias Plug.Conn
  alias Pow.Plug
  alias Philomena.Users

  alias PhilomenaWeb.UserIpUpdater
  alias PhilomenaWeb.UserFingerprintUpdater

  def init(opts), do: opts

  def call(conn, _opts) do
    config = Plug.fetch_config(conn)

    case Plug.current_user(conn, config) do
      nil ->
        conn

      user ->
        update_usages(conn, user)
        reloaded_user = Users.get_by(id: user.id)

        Plug.assign_current_user(conn, reloaded_user, config)
    end
  end

  defp update_usages(conn, user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    conn = Conn.fetch_cookies(conn)

    UserIpUpdater.cast(user.id, conn.remote_ip, now)
    UserFingerprintUpdater.cast(user.id, conn.cookies["_ses"], now)
  end
end
