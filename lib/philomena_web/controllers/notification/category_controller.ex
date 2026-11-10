defmodule PhilomenaWeb.Notification.CategoryController do
  use PhilomenaWeb, :controller

  alias Philomena.Notifications

  action_fallback PhilomenaWeb.FallbackController

  def show(conn, params) do
    with {:ok, {category, notifications}} <-
           Notifications.show_unread_notification_category(
             conn.assigns.actor,
             params["id"],
             conn.assigns.scrivener
           ) do
      render(conn, "show.html",
        title: "Notification Area",
        notifications: notifications,
        category: category
      )
    end
  end
end
