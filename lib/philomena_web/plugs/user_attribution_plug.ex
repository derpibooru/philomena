defmodule PhilomenaWeb.UserAttributionPlug do
  @moduledoc """
  This plug stores information about the current session for use in
  model attribution.

  ## Example

      plug PhilomenaWeb.UserAttributionPlug
  """

  alias Philomena.Attribution.Actor
  alias Philomena.Bans
  alias Plug.Conn

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(conn, _opts) do
    {:ok, ip} = EctoNetwork.INET.cast(conn.remote_ip)
    fingerprint = conn.assigns.fingerprint
    user = conn.assigns.current_user

    ban = Bans.find(user, ip, fingerprint)

    actor = %Actor{
      ip: ip,
      fingerprint: fingerprint,
      user: user,
      ban: ban
    }

    conn
    |> Conn.assign(:actor, actor)
    |> Conn.assign(:current_ban, ban)
  end
end
