defmodule PhilomenaWeb.NotificationController do
  use PhilomenaWeb, :controller

  alias Philomena.Notifications

  def index(conn, _params) do
    notifications =
      Notifications.unread_notifications_for_user(
        conn.assigns.current_user,
        page_size: 10
      )

    render(conn, "index.html", title: "Notification Area", notifications: notifications)
  end
end
