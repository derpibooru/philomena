defmodule PhilomenaWeb.Notification.CategoryView do
  use PhilomenaWeb, :view

  defdelegate name_of_type(type), to: PhilomenaWeb.NotificationView
end
