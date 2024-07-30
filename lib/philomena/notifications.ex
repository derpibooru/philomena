defmodule Philomena.Notifications do
  @moduledoc """
  The Notifications context.
  """

  import Ecto.Query, warn: false

  alias Philomena.Channels.Subscription, as: ChannelSubscription
  alias Philomena.Forums.Subscription, as: ForumSubscription
  alias Philomena.Galleries.Subscription, as: GallerySubscription
  alias Philomena.Images.Subscription, as: ImageSubscription
  alias Philomena.Topics.Subscription, as: TopicSubscription

  alias Philomena.Notifications.ChannelLiveNotification
  alias Philomena.Notifications.ForumPostNotification
  alias Philomena.Notifications.ForumTopicNotification
  alias Philomena.Notifications.GalleryImageNotification
  alias Philomena.Notifications.ImageCommentNotification
  alias Philomena.Notifications.ImageMergeNotification

  alias Philomena.Notifications.Category
  alias Philomena.Notifications.Creator

  @doc """
  Return the count of all currently unread notifications for the user in all categories.

  ## Examples

      iex> total_unread_notification_count(user)
      15

  """
  def total_unread_notification_count(user) do
    Category.total_unread_notification_count(user)
  end

  @doc """
  Gather up and return the top N notifications for the user, for each category of
  unread notification currently existing.

  ## Examples

      iex> unread_notifications_for_user(user, page_size: 10)
      [
        channel_live: [],
        forum_post: [%ForumPostNotification{...}, ...],
        forum_topic: [%ForumTopicNotification{...}, ...],
        gallery_image: [],
        image_comment: [%ImageCommentNotification{...}, ...],
        image_merge: []
      ]

  """
  def unread_notifications_for_user(user, pagination) do
    Category.unread_notifications_for_user(user, pagination)
  end

  @doc """
  Returns paginated unread notifications for the user, given the category.

  ## Examples

      iex> unread_notifications_for_user_and_category(user, :image_comment)
      [%ImageCommentNotification{...}]

  """
  def unread_notifications_for_user_and_category(user, category, pagination) do
    Category.unread_notifications_for_user_and_category(user, category, pagination)
  end

  @doc """
  Creates a channel live notification, returning the number of affected users.

  ## Examples

      iex> create_channel_live_notification(channel)
      {:ok, 2}

  """
  def create_channel_live_notification(channel) do
    Creator.create_single(
      where(ChannelSubscription, channel_id: ^channel.id),
      ChannelLiveNotification,
      nil,
      :channel_id,
      channel
    )
  end

  @doc """
  Creates a forum post notification, returning the number of affected users.

  ## Examples

      iex> create_forum_post_notification(user, topic, post)
      {:ok, 2}

  """
  def create_forum_post_notification(user, topic, post) do
    Creator.create_double(
      where(TopicSubscription, topic_id: ^topic.id),
      ForumPostNotification,
      user,
      :topic_id,
      topic,
      :post_id,
      post
    )
  end

  @doc """
  Creates a forum topic notification, returning the number of affected users.

  ## Examples

      iex> create_forum_topic_notification(user, topic)
      {:ok, 2}

  """
  def create_forum_topic_notification(user, topic) do
    Creator.create_single(
      where(ForumSubscription, forum_id: ^topic.forum_id),
      ForumTopicNotification,
      user,
      :topic_id,
      topic
    )
  end

  @doc """
  Creates a gallery image notification, returning the number of affected users.

  ## Examples

      iex> create_gallery_image_notification(gallery)
      {:ok, 2}

  """
  def create_gallery_image_notification(gallery) do
    Creator.create_single(
      where(GallerySubscription, gallery_id: ^gallery.id),
      GalleryImageNotification,
      nil,
      :gallery_id,
      gallery
    )
  end

  @doc """
  Creates an image comment notification, returning the number of affected users.

  ## Examples

      iex> create_image_comment_notification(user, image, comment)
      {:ok, 2}

  """
  def create_image_comment_notification(user, image, comment) do
    Creator.create_double(
      where(ImageSubscription, image_id: ^image.id),
      ImageCommentNotification,
      user,
      :image_id,
      image,
      :comment_id,
      comment
    )
  end

  @doc """
  Creates an image merge notification, returning the number of affected users.

  ## Examples

      iex> create_image_merge_notification(target, source)
      {:ok, 2}

  """
  def create_image_merge_notification(target, source) do
    Creator.create_double(
      where(ImageSubscription, image_id: ^target.id),
      ImageMergeNotification,
      nil,
      :target_id,
      target,
      :source_id,
      source
    )
  end

  @doc """
  Removes the channel live notification for a given channel and user, returning
  the number of affected users.

  ## Examples

      iex> clear_channel_live_notification(channel, user)
      {:ok, 2}

  """
  def clear_channel_live_notification(channel, user) do
    ChannelLiveNotification
    |> where(channel_id: ^channel.id)
    |> Creator.clear(user)
  end

  @doc """
  Removes the forum post notification for a given topic and user, returning
  the number of affected notifications.

  ## Examples

      iex> clear_forum_post_notification(topic, user)
      {:ok, 2}

  """
  def clear_forum_post_notification(topic, user) do
    ForumPostNotification
    |> where(topic_id: ^topic.id)
    |> Creator.clear(user)
  end

  @doc """
  Removes the forum topic notification for a given topic and user, returning
  the number of affected notifications.

  ## Examples

      iex> clear_forum_topic_notification(topic, user)
      {:ok, 2}

  """
  def clear_forum_topic_notification(topic, user) do
    ForumTopicNotification
    |> where(topic_id: ^topic.id)
    |> Creator.clear(user)
  end

  @doc """
  Removes the gallery image notification for a given gallery and user, returning
  the number of affected notifications.

  ## Examples

      iex> clear_gallery_image_notification(topic, user)
      {:ok, 2}

  """
  def clear_gallery_image_notification(gallery, user) do
    GalleryImageNotification
    |> where(gallery_id: ^gallery.id)
    |> Creator.clear(user)
  end

  @doc """
  Removes the image comment notification for a given image and user, returning
  the number of affected notifications.

  ## Examples

      iex> clear_gallery_image_notification(topic, user)
      {:ok, 2}

  """
  def clear_image_comment_notification(image, user) do
    ImageCommentNotification
    |> where(image_id: ^image.id)
    |> Creator.clear(user)
  end

  @doc """
  Removes the image merge notification for a given image and user, returning
  the number of affected notifications.

  ## Examples

      iex> clear_image_merge_notification(topic, user)
      {:ok, 2}

  """
  def clear_image_merge_notification(image, user) do
    ImageMergeNotification
    |> where(target_id: ^image.id)
    |> Creator.clear(user)
  end
end
