defmodule PhilomenaWeb.BanView do
  use PhilomenaWeb, :view

  def active?(ban) do
    NaiveDateTime.diff(ban.valid_until, NaiveDateTime.utc_now()) > 0
  end
end
