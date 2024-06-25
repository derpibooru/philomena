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
    fingerprint = conn.assigns.fingerprint
    user = conn.assigns.current_user
    ip = conn.remote_ip

    ban = Bans.find(user, ip, fingerprint)

    Conn.assign(conn, :current_ban, ban)
  end
end
