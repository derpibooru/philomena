defmodule PhilomenaWeb.Notification.UnreadController do
  use PhilomenaWeb, :controller

  def index(conn, _params) do
    json(conn, %{
      notifications: conn.assigns.notification_count,
      conversations: conn.assigns.conversation_count
    })
  end
end