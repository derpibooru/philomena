defmodule PhilomenaWeb.ChannelView do
  use PhilomenaWeb, :view

  def channel_image(%{channel_image: image, is_live: false}) when image not in [nil, ""],
    do: channel_url_root() <> "/" <> image

  def channel_image(%{type: "LivestreamChannel", short_name: short_name}) do
    now = DateTime.utc_now() |> DateTime.to_unix(:microsecond)
    Camo.Image.image_url("https://thumbnail.api.livestream.com/thumbnail?name=#{short_name}&rand=#{now}")
  end

  def channel_image(%{type: "PicartoChannel", thumbnail_url: thumbnail_url}),
    do: Camo.Image.image_url(thumbnail_url || "https://picarto.tv/images/missingthumb.jpg")

  def channel_image(%{type: "PiczelChannel", remote_stream_id: remote_stream_id}),
    do: Camo.Image.image_url("https://piczel.tv/api/thumbnail/stream_#{remote_stream_id}.jpg")
  
  def channel_image(%{type: "TwitchChannel", short_name: short_name}),
    do: Camo.Image.image_url("https://static-cdn.jtvnw.net/previews-ttv/live_user_#{String.downcase(short_name)}-320x180.jpg")

  defp channel_url_root do
    Application.get_env(:philomena, :channel_url_root)
  end
end
