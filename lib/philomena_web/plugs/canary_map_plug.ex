defmodule PhilomenaWeb.CanaryMapPlug do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, opts) do
    phx_action = conn.private.phoenix_action
    canary_action =
      case Keyword.fetch(opts, phx_action) do
        {:ok, action} -> action
        _             -> phx_action
      end

    conn
    |> assign(:canary_action, canary_action)
  end
end