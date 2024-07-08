defmodule PhilomenaWeb.Notification.CategoryController do
  use PhilomenaWeb, :controller

  alias Philomena.Notifications

  def show(conn, params) do
    type = category(params)

    notifications =
      Notifications.unread_notifications_for_user_and_type(
        conn.assigns.current_user,
        type,
        conn.assigns.scrivener
      )

    render(conn, "show.html",
      title: "Notification Area",
      notifications: notifications,
      type: type
    )
  end

  defp category(params) do
    case params["id"] do
      "channel_live" -> :channel_live
      "gallery_image" -> :gallery_image
      "image_comment" -> :image_comment
      "image_merge" -> :image_merge
      "forum_topic" -> :forum_topic
      _ -> :forum_post
    end
  end
end
