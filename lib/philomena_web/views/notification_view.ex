defmodule PhilomenaWeb.NotificationView do
  use PhilomenaWeb, :view

  @template_paths %{
    "Channel" => "_channel.html",
    "Forum" => "_forum.html",
    "Gallery" => "_gallery.html",
    "Image" => "_image.html",
    "LivestreamChannel" => "_channel.html",
    "Topic" => "_topic.html"
  }

  def notification_template_path(actor_type) do
    @template_paths[actor_type]
  end
end
