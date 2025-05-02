defmodule PhilomenaWeb.Admin.AdvertView do
  use PhilomenaWeb, :view

  alias PhilomenaWeb.AdvertView

  defp advert_image_url(advert),
    do: AdvertView.advert_image_url(advert)

  def time_column_class(other_time) do
    now = DateTime.utc_now()

    if DateTime.diff(other_time, now) > 0 do
      "success"
    else
      "danger"
    end
  end

  def live_text(%{live: true}), do: "Yes"
  def live_text(_advert), do: "No"

  def restrictions do
    [
      [key: "Display on all images", value: "none"],
      [key: "Display on NSFW images only", value: "nsfw"],
      [key: "Display on SFW images only", value: "sfw"]
    ]
  end
end
