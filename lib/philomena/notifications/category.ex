defmodule Philomena.Notifications.Category do
  @moduledoc """
  Notification category determination.
  """

  import Ecto.Query, warn: false
  alias Philomena.Notifications.Notification

  @type t ::
          :channel_live
          | :forum_post
          | :forum_topic
          | :gallery_image
          | :image_comment
          | :image_merge

  @doc """
  Return a list of all supported types.
  """
  def types do
    [
      :channel_live,
      :forum_topic,
      :gallery_image,
      :image_comment,
      :image_merge,
      :forum_post
    ]
  end

  @doc """
  Determine the type of a `m:Philomena.Notifications.Notification`.
  """
  def notification_type(n) do
    case {n.actor_type, n.actor_child_type} do
      {"Channel", _} ->
        :channel_live

      {"Gallery", _} ->
        :gallery_image

      {"Image", "Comment"} ->
        :image_comment

      {"Image", _} ->
        :image_merge

      {"Topic", "Post"} ->
        if n.action == "posted a new reply in" do
          :forum_post
        else
          :forum_topic
        end
    end
  end

  @doc """
  Returns an `m:Ecto.Query` that finds notifications for the given type.
  """
  def query_for_type(type) do
    base = from(n in Notification)

    case type do
      :channel_live ->
        where(base, [n], n.actor_type == "Channel")

      :gallery_image ->
        where(base, [n], n.actor_type == "Gallery")

      :image_comment ->
        where(base, [n], n.actor_type == "Image" and n.actor_child_type == "Comment")

      :image_merge ->
        where(base, [n], n.actor_type == "Image" and is_nil(n.actor_child_type))

      :forum_topic ->
        where(
          base,
          [n],
          n.actor_type == "Topic" and n.actor_child_type == "Post" and
            n.action != "posted a new reply in"
        )

      :forum_post ->
        where(
          base,
          [n],
          n.actor_type == "Topic" and n.actor_child_type == "Post" and
            n.action == "posted a new reply in"
        )
    end
  end
end
