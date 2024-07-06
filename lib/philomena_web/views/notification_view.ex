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

  def name_of_type(notification_type) do
    case notification_type do
      :channel_live ->
        "Live channels"

      :forum_post ->
        "New replies in topics"

      :forum_topic ->
        "New topics"

      :gallery_image ->
        "Updated galleries"

      :image_comment ->
        "New replies on images"

      :image_merge ->
        "Image merges"
    end
  end
end
