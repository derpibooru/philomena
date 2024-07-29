defmodule PhilomenaWeb.NotificationView do
  use PhilomenaWeb, :view

  @template_paths %{
    "channel_live" => "_channel.html",
    "forum_post" => "_post.html",
    "forum_topic" => "_topic.html",
    "gallery_image" => "_gallery.html",
    "image_comment" => "_comment.html",
    "image_merge" => "_image.html"
  }

  def notification_template_path(category) do
    @template_paths[to_string(category)]
  end

  def name_of_category(category) do
    case category do
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
