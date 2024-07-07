defmodule PhilomenaWeb.Channel.ReadController do
  import Plug.Conn
  use PhilomenaWeb, :controller

  alias Philomena.Channels.Channel
  alias Philomena.Channels

  plug :load_resource, model: Channel, id_name: "channel_id", persisted: true

  def create(conn, _params) do
    channel = conn.assigns.channel
    user = conn.assigns.current_user

    Channels.clear_channel_notification(channel, user)

    send_resp(conn, :ok, "")
  end
end
