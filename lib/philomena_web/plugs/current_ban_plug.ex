defmodule PhilomenaWeb.CurrentBanPlug do
  @moduledoc """
  This plug loads the ban for the current user.

  ## Example

      plug PhilomenaWeb.CurrentBanPlug
  """
  alias Philomena.Bans
  alias Plug.Conn

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Conn.t(), any()) :: Conn.t()
  def call(conn, _opts) do
    conn = Conn.fetch_cookies(conn)

    fingerprint = conn.cookies["_ses"]
    user = conn.assigns.current_user
    ip = conn.remote_ip

    ban = Bans.exists_for?(user, ip, fingerprint)

    Conn.assign(conn, :current_ban, ban)
  end
end
