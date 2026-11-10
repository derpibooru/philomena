defmodule PhilomenaWeb.ChannelPlug do
  alias Plug.Conn
  alias Philomena.Channels

  def init([]), do: []

  def call(conn, _opts) do
    Conn.assign(conn, :live_channels, Channels.count_live_channels())
  end
end
