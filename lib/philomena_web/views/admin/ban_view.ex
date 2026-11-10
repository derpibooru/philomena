defmodule PhilomenaWeb.Admin.BanView do
  alias PhilomenaWeb.ProfileView

  def user_abbrv(user),
    do: ProfileView.user_abbrv(user)

  def ban_row_class(%{valid_until: until, enabled: enabled}) do
    now = DateTime.utc_now()

    if enabled and DateTime.diff(until, now) > 0 do
      "success"
    else
      "danger"
    end
  end

  def page_params(params) do
    params
    |> Map.take(["bq", "fingerprint", "ip", "user_id"])
    |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
  end
end
