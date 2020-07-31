defmodule PhilomenaWeb.UserAttributionPlug do
  @moduledoc """
  This plug stores information about the current session for use in
  model attribution.

  ## Example

      plug PhilomenaWeb.UserAttributionPlug
  """

  alias Plug.Conn

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(conn, _opts) do
    {:ok, remote_ip} = EctoNetwork.INET.cast(conn.remote_ip)
    conn = Conn.fetch_cookies(conn)
    user = conn.assigns.current_user

    attributes = [
      ip: remote_ip,
      fingerprint: fingerprint(conn, conn.path_info),
      referrer: conn.assigns.referrer,
      user: user,
      user_agent: user_agent(conn)
    ]

    conn
    |> Conn.assign(:attributes, attributes)
  end

  defp user_agent(conn) do
    case Conn.get_req_header(conn, "user-agent") do
      [ua] -> ua
      _ -> nil
    end
  end

  defp fingerprint(conn, ["api" | _]) do
    "a#{:erlang.crc32(user_agent(conn))}"
  end

  defp fingerprint(conn, _) do
    conn.cookies["_ses"]
  end
end
