defmodule PhilomenaWeb.Admin.SubnetBanView do
  use PhilomenaWeb, :view

  alias PhilomenaWeb.ProfileView

  defp user_abbrv(conn, user),
    do: ProfileView.user_abbrv(conn, user)

  defp ban_row_class(%{valid_until: until, enabled: enabled}) do
    now = DateTime.utc_now()

    case enabled and DateTime.diff(until, now) > 0 do
      true   -> "success"
      _false -> "danger"
    end
  end
end
