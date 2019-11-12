defmodule PhilomenaWeb.ProfileView do
  use PhilomenaWeb, :view

  def award_order(awards) do
    awards
    |> Enum.sort_by(&{!&1.badge.priority, &1.awarded_on})
  end

  def badge_image(badge, options \\ []) do
    img_tag(badge_url_root() <> "/" <> badge.image, options)
  end

  def award_title(%{badge_name: nil} = award),
    do: award.badge.title
  def award_title(%{badge_name: ""} = award),
    do: award.badge.title
  def award_title(award),
    do: award.badge_name

  defp badge_url_root do
    Application.get_env(:philomena, :badge_url_root)
  end
end