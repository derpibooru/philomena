defmodule PhilomenaWeb.Admin.BadgeView do
  use PhilomenaWeb, :view

  alias PhilomenaWeb.ProfileView

  defp badge_image(badge, options),
    do: ProfileView.badge_image(badge, options)
end
