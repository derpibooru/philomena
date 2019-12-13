defmodule PhilomenaWeb.Admin.UserBanView do
  use PhilomenaWeb, :view

  import PhilomenaWeb.ProfileView, only: [user_abbrv: 2]

  defp ban_row_class(%{valid_until: until, enabled: enabled}) do
    now = DateTime.utc_now()

    case enabled and DateTime.diff(until, now) > 0 do
      true   -> "success"
      _false -> "danger"
    end
  end
end
