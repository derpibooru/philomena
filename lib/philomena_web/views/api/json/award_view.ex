defmodule PhilomenaWeb.Api.Json.AwardView do
  use PhilomenaWeb, :view

  def render("award.json", %{award: award}) do
    %{
      image_url: badge_url_root() <> "/" <> award.badge.image,
      title: award.badge.title,
      id: award.badge_id,
      label: award.label,
      awarded_on: award.awarded_on
    }
  end

  defp badge_url_root do
    Application.get_env(:philomena, :badge_url_root)
  end
end
