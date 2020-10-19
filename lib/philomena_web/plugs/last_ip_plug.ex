defmodule PhilomenaWeb.LastIpPlug do
  @moduledoc """
  This plug stores the connecting IP address in the session.
  ## Example

      plug PhilomenaWeb.LastIpPlug
  """

  alias Plug.Conn

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Conn.t(), any()) :: Conn.t()
  def call(conn, _opts) do
    {:ok, ip} = EctoNetwork.INET.cast(conn.remote_ip)

    conn
    |> Conn.fetch_session()
    |> Conn.put_session(:remote_ip, to_string(ip))
  end
end
