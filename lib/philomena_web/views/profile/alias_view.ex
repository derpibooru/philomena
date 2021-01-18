defmodule PhilomenaWeb.Profile.AliasView do
  use PhilomenaWeb, :view

  def younger_than_7_days?(user),
    do: younger_than_time_offset?(user, -7 * 24 * 60 * 60)

  def younger_than_14_days?(user),
    do: younger_than_time_offset?(user, -14 * 24 * 60 * 60)

  def currently_banned?(%{bans: bans}) do
    now = DateTime.utc_now()

    Enum.any?(bans, &(DateTime.diff(&1.valid_until, now) >= 0))
  end

  def previously_banned?(%{bans: []}), do: false
  def previously_banned?(_user), do: true

  defp younger_than_time_offset?(%{created_at: created_at}, time_offset) do
    time_ago = DateTime.utc_now() |> DateTime.add(-time_offset, :second)

    DateTime.diff(created_at, time_ago) >= 0
  end
end
