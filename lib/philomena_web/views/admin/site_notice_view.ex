defmodule PhilomenaWeb.Admin.SiteNoticeView do
  use PhilomenaWeb, :view

  def time_column_class(time) do
    now = DateTime.utc_now()

    if DateTime.diff(time, now) > 0 do
      "success"
    else
      "danger"
    end
  end

  def live_text(%{live: true}), do: "Yes"
  def live_text(_site_notice), do: "No"
end
