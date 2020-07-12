defmodule PhilomenaWeb.StaffView do
  use PhilomenaWeb, :view

  def unavailable?(user),
    do: user.hide_default_role && user.secondary_role in [nil, ""]

end
