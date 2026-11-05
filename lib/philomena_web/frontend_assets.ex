defmodule PhilomenaWeb.FrontendAssets do
  @moduledoc "Helpers for development and compiled frontend asset URLs."

  @vite_port 5173

  @spec vite_origin(Plug.Conn.t()) :: String.t()
  def vite_origin(%Plug.Conn{host: host}) do
    URI.to_string(%URI{scheme: "http", host: host, port: @vite_port})
  end

  @spec vite_asset_url(Plug.Conn.t(), String.t()) :: String.t()
  def vite_asset_url(conn, path) when is_binary(path) do
    vite_origin(conn) <> "/" <> String.trim_leading(path, "/")
  end

  @spec vite_websocket_origin(Plug.Conn.t()) :: String.t()
  def vite_websocket_origin(%Plug.Conn{host: host}) do
    URI.to_string(%URI{scheme: "ws", host: host, port: @vite_port})
  end
end
