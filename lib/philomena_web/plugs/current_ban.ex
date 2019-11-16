defmodule PhilomenaWeb.Plugs.CurrentBan do
  @moduledoc """
  This plug loads the ban for the current user.

  ## Example

      plug PhilomenaWeb.Plugs.Ban
  """
  alias Philomena.Bans
  alias Plug.Conn
  alias Pow.Plug

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Conn.t(), any()) :: Conn.t()
  def call(conn, _opts) do
    conn =
      conn
      |> Conn.fetch_cookies()

    fingerprint = conn.cookies["_ses"]
    user = Plug.current_user(conn)
    ip = conn.remote_ip

    ban = Bans.exists_for?(user, ip, fingerprint)

    Conn.assign(conn, :current_ban, ban)
  end
end