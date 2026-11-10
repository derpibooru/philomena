defmodule PhilomenaWeb.NotificationController do
  use PhilomenaWeb, :controller

  alias Philomena.Notifications

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, _params) do
    with {:ok, notifications} <-
           Notifications.list_unread_notifications(conn.assigns.actor, page_size: 10) do
      render(conn, "index.html", title: "Notification Area", notifications: notifications)
    end
  end
end
