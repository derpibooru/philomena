defmodule PhilomenaWeb.ChannelView do
  use PhilomenaWeb, :view

  def channel_image(%{thumbnail_url: thumbnail_url}) do
    PhilomenaProxy.Camo.image_url(thumbnail_url || "https://picarto.tv/images/missingthumb.jpg")
  end
end
