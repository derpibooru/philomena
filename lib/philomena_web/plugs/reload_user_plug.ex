defmodule PhilomenaWeb.ReloadUserPlug do
  alias Plug.Conn
  alias Pow.Plug
  alias Philomena.Users

  alias Philomena.UserIps.UserIp
  alias Philomena.UserFingerprints.UserFingerprint
  alias Philomena.Repo
  import Ecto.Query

  def init(opts), do: opts

  def call(conn, _opts) do
    config = Plug.fetch_config(conn)

    case Plug.current_user(conn, config) do
      nil ->
        conn

      user ->
        spawn fn -> update_usages(conn, user) end
        reloaded_user = Users.get_by(id: user.id)

        Plug.assign_current_user(conn, reloaded_user, config)
    end
  end

  # TODO: move this to a background server instead of spawning
  # off for every connection
  defp update_usages(conn, user) do
    conn = Conn.fetch_cookies(conn)

    {:ok, ip} = EctoNetwork.INET.cast(conn.remote_ip)
    fp = conn.cookies["_ses"]

    if ip do
      update = update(UserIp, inc: [uses: 1], set: [updated_at: fragment("now()")])

      Repo.insert_all(
        UserIp,
        [%{user_id: user.id, ip: ip, uses: 1}],
        conflict_target: [:user_id, :ip],
        on_conflict: update
      )
    end

    if fp do
      update = update(UserFingerprint, inc: [uses: 1], set: [updated_at: fragment("now()")])

      Repo.insert_all(
        UserFingerprint,
        [%{user_id: user.id, fingerprint: fp, uses: 1}],
        conflict_target: [:user_id, :fingerprint],
        on_conflict: update
      )
    end
  end
end
