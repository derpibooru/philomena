defmodule PhilomenaWeb.Notification.CategoryView do
  use PhilomenaWeb, :view

  defdelegate name_of_category(category), to: PhilomenaWeb.NotificationView
  defdelegate notification_template_path(category), to: PhilomenaWeb.NotificationView
end
