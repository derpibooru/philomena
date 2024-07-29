defmodule Philomena.Notifications.Category do
  @moduledoc """
  Notification category querying.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Notifications.ChannelLiveNotification
  alias Philomena.Notifications.ForumPostNotification
  alias Philomena.Notifications.ForumTopicNotification
  alias Philomena.Notifications.GalleryImageNotification
  alias Philomena.Notifications.ImageCommentNotification
  alias Philomena.Notifications.ImageMergeNotification

  @type t ::
          :channel_live
          | :forum_post
          | :forum_topic
          | :gallery_image
          | :image_comment
          | :image_merge

  @doc """
  Return a list of all supported categories.
  """
  def categories do
    [
      :channel_live,
      :forum_post,
      :forum_topic,
      :gallery_image,
      :image_comment,
      :image_merge
    ]
  end

  @doc """
  Return the count of all currently unread notifications for the user in all categories.

  ## Examples

      iex> total_unread_notification_count(user)
      15

  """
  def total_unread_notification_count(user) do
    categories()
    |> Enum.map(fn category ->
      category
      |> query_for_category_and_user(user)
      |> exclude(:preload)
      |> select([_], %{one: 1})
    end)
    |> union_all_queries()
    |> Repo.aggregate(:count)
  end

  defp union_all_queries([query | rest]) do
    Enum.reduce(rest, query, fn q, acc -> union_all(acc, ^q) end)
  end

  @doc """
  Gather up and return the top N notifications for the user, for each category of
  unread notification currently existing.

  ## Examples

      iex> unread_notifications_for_user(user, page_size: 10)
      %{
        channel_live: [],
        forum_post: [%ForumPostNotification{...}, ...],
        forum_topic: [%ForumTopicNotification{...}, ...],
        gallery_image: [],
        image_comment: [%ImageCommentNotification{...}, ...],
        image_merge: []
      }

  """
  def unread_notifications_for_user(user, pagination) do
    Map.new(categories(), fn category ->
      results =
        category
        |> query_for_category_and_user(user)
        |> order_by(desc: :updated_at)
        |> Repo.paginate(pagination)

      {category, results}
    end)
  end

  @doc """
  Returns paginated unread notifications for the user, given the category.

  ## Examples

      iex> unread_notifications_for_user_and_category(user, :image_comment)
      [%ImageCommentNotification{...}]

  """
  def unread_notifications_for_user_and_category(user, category, pagination) do
    category
    |> query_for_category_and_user(user)
    |> order_by(desc: :updated_at)
    |> Repo.paginate(pagination)
  end

  @doc """
  Determine the category of a notification.

  ## Examples

      iex> notification_category(%ImageCommentNotification{})
      :image_comment

  """
  def notification_category(n) do
    case n.__struct__ do
      ChannelLiveNotification -> :channel_live
      GalleryImageNotification -> :gallery_image
      ImageCommentNotification -> :image_comment
      ImageMergeNotification -> :image_merge
      ForumPostNotification -> :forum_post
      ForumTopicNotification -> :forum_topic
    end
  end

  @doc """
  Returns an `m:Ecto.Query` that finds unread notifications for the given category,
  for the given user, with preloads applied.

  ## Examples

      iex> query_for_category_and_user(:channel_live, user)
      #Ecto.Query<from c0 in ChannelLiveNotification, where: c0.user_id == ^1, preload: [:channel]>

  """
  def query_for_category_and_user(category, user) do
    query =
      case category do
        :channel_live ->
          from(n in ChannelLiveNotification, preload: :channel)

        :gallery_image ->
          from(n in GalleryImageNotification, preload: [gallery: :creator])

        :image_comment ->
          from(n in ImageCommentNotification,
            preload: [image: [:sources, tags: :aliases], comment: :user]
          )

        :image_merge ->
          from(n in ImageMergeNotification,
            preload: [:source, target: [:sources, tags: :aliases]]
          )

        :forum_topic ->
          from(n in ForumTopicNotification, preload: [topic: [:forum, :user]])

        :forum_post ->
          from(n in ForumPostNotification, preload: [topic: :forum, post: :user])
      end

    where(query, user_id: ^user.id)
  end
end
