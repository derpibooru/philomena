defmodule PhilomenaWeb.FirehoseChannel do
  use Phoenix.Channel

  def join("firehose", _params, socket) do
    {:ok, socket}
  end

  def join(_room, _params, _socket) do
    {:error, %{reason: "not_found"}}
  end

  # Don't allow the connected client to send any messages to the socket
  def handle_in(message, _params, socket) do
    {:stop, :shutdown, socket}
  end
end
