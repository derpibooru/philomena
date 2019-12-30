defmodule PhilomenaWeb.BanView do
  use PhilomenaWeb, :view

  def active?(ban) do
    ban.enabled and NaiveDateTime.diff(ban.valid_until, NaiveDateTime.utc_now()) > 0
  end
end
