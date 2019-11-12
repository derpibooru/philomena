defmodule PhilomenaWeb.ProfileView do
  use PhilomenaWeb, :view

  def award_order(awards) do
    awards
    |> Enum.sort_by(&{!&1.badge.priority, &1.awarded_on})
  end

  def badge_image(badge, options \\ []) do
    img_tag(badge_url_root() <> "/" <> badge.image, options)
  end

  defp badge_url_root do
    Application.get_env(:philomena, :badge_url_root)
  end
end