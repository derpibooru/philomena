defmodule Philomena.Notifications do
  @moduledoc """
  Notification reads and internal event delivery.

  At most one unread row exists per recipient and event subject, and a repeated
  broadcast refreshes it without changing its original creation time.

  Event owners call these services from `Philomena.Multi.run/3`, so their
  database changes and notifications commit or roll back together.
  """

  import Ecto.Query, warn: false

  alias Philomena.Attribution.Actor
  alias Philomena.Channels
  alias Philomena.Channels.Channel
  alias Philomena.Comments.Comment
  alias Philomena.Forums
  alias Philomena.Galleries
  alias Philomena.Galleries.Gallery
  alias Philomena.Images
  alias Philomena.Images.Image
  alias Philomena.Multi
  alias Philomena.Notifications.ChannelLiveNotification
  alias Philomena.Notifications.ForumPostNotification
  alias Philomena.Notifications.ForumTopicNotification
  alias Philomena.Notifications.GalleryImageNotification
  alias Philomena.Notifications.ImageCommentNotification
  alias Philomena.Notifications.ImageMergeNotification
  alias Philomena.Posts.Post
  alias Philomena.Repo
  alias Philomena.Topics
  alias Philomena.Topics.Topic
  alias Philomena.Users.User

  @categories [
    :channel_live,
    :forum_post,
    :forum_topic,
    :gallery_image,
    :image_comment,
    :image_merge
  ]

  @category_params Map.new(@categories, &{Atom.to_string(&1), &1})

  @typedoc "A category of unread notifications."
  @type category ::
          :channel_live
          | :forum_post
          | :forum_topic
          | :gallery_image
          | :image_comment
          | :image_merge

  @typedoc "The number of notification rows affected by a broadcast or clear."
  @type count_result :: {:ok, non_neg_integer()}

  defp category_query(category) do
    case category do
      :channel_live ->
        from(n in ChannelLiveNotification, preload: :channel)

      :gallery_image ->
        from(n in GalleryImageNotification, preload: [gallery: :user])

      :forum_post ->
        from(n in ForumPostNotification, preload: [topic: :forum, post: :user])

      :forum_topic ->
        from(n in ForumTopicNotification, preload: [topic: [:forum, :user]])

      :image_comment ->
        from(n in ImageCommentNotification,
          preload: [image: [:sources, tags: :aliases], comment: :user]
        )

      :image_merge ->
        from(n in ImageMergeNotification,
          preload: [:source, target: [:sources, tags: :aliases]]
        )
    end
  end

  defp user_category_query(category, %User{} = user) do
    category
    |> category_query()
    |> where(user_id: ^user.id)
  end

  defp unread_page(category, %User{} = user, pagination) do
    category
    |> user_category_query(user)
    |> order_by(desc: :updated_at)
    |> Repo.paginate(pagination)
  end

  defp subscription_query(subscription, author) do
    case author do
      %User{id: user_id} ->
        # Avoid sending notifications to the user which performed the action
        from(row in subscription, where: row.user_id != ^user_id)

      _anonymous_author ->
        # When not created by a user, send notifications to all subscribers
        subscription
    end
  end

  defp convert_to_notification(subscription, extra) do
    now = dynamic([_row], type(^DateTime.utc_now(:second), :utc_datetime))

    base = %{
      user_id: dynamic([subscription], subscription.user_id),
      created_at: now,
      updated_at: now,
      read: false
    }

    extra =
      Map.new(extra, fn {field, value} ->
        {field, dynamic([_row], type(^value, :integer))}
      end)

    from(subscription, select: ^Map.merge(base, extra))
  end

  defp insert_notifications(query, notification, unique_key) do
    {count, nil} =
      Repo.insert_all(
        notification,
        query,
        on_conflict: {:replace_all_except, [:created_at]},
        conflict_target: [unique_key, :user_id]
      )

    {:ok, count}
  end

  defp broadcast_notification(opts) do
    opts = Keyword.validate!(opts, [:notification_author, :from, :into, :select, :unique_key])

    notification_author = Keyword.get(opts, :notification_author)
    {subscription_schema, filters} = Keyword.fetch!(opts, :from)
    notification_schema = Keyword.fetch!(opts, :into)
    select_keywords = Keyword.fetch!(opts, :select)
    unique_key = Keyword.fetch!(opts, :unique_key)

    subscription_schema
    |> subscription_query(notification_author)
    |> where(^filters)
    |> convert_to_notification(select_keywords)
    |> insert_notifications(notification_schema, unique_key)
  end

  defp clear_for_user(_query, nil), do: {:ok, 0}

  defp clear_for_user(query, %User{} = user) do
    {count, nil} =
      query
      |> where(user_id: ^user.id)
      |> Repo.delete_all()

    {:ok, count}
  end

  @doc """
  Parses a notification category route parameter.

  Unknown categories are `{:error, :not_found}`.

  ## Examples

      iex> parse_category("image_comment")
      {:ok, :image_comment}

      iex> parse_category("unknown")
      {:error, :not_found}

  """
  @spec parse_category(any()) :: {:ok, category()} | {:error, :not_found}
  def parse_category(param) when is_binary(param) do
    case Map.fetch(@category_params, param) do
      {:ok, category} -> {:ok, category}
      :error -> {:error, :not_found}
    end
  end

  def parse_category(_param), do: {:error, :not_found}

  @doc """
  Counts unread notifications belonging to `actor`'s user.

  Anonymous actors receive zero.

  ## Examples

      iex> total_unread_count(actor)
      15

      iex> total_unread_count(anonymous_actor)
      0

  """
  @spec total_unread_count(Actor.t()) :: non_neg_integer()
  def total_unread_count(%Actor{user: nil}), do: 0

  def total_unread_count(%Actor{user: %User{} = user}) do
    queries =
      Enum.map(@categories, fn category ->
        category
        |> user_category_query(user)
        |> exclude(:preload)
        |> select([_notification], %{one: 1})
      end)

    queries
    |> Enum.reduce(&union_all(&2, ^&1))
    |> Repo.aggregate(:count)
  end

  @doc """
  Loads paginated notifications for every unread category belonging to `actor`.

  Anonymous actors are considered unauthorized.

  ## Examples

      iex> list_unread_notifications(actor, page_size: 10)
      {:ok, [channel_live: %Scrivener.Page{}, ...]}

      iex> list_unread_notifications(anonymous_actor, page_size: 10)
      {:error, :unauthorized}

  """
  @spec list_unread_notifications(Actor.t(), Repo.pagination_params()) ::
          {:ok, [{category(), Scrivener.Page.t()}]} | {:error, :unauthorized}
  def list_unread_notifications(%Actor{user: nil}, _pagination), do: {:error, :unauthorized}

  def list_unread_notifications(%Actor{user: %User{} = user}, pagination) do
    unread =
      Enum.map(@categories, fn category ->
        {category, unread_page(category, user, pagination)}
      end)

    {:ok, unread}
  end

  @doc """
  Loads one parsed unread category belonging to `actor`.

  Returns the parsed category with its page. Unknown categories are
  `{:error, :not_found}`.

  ## Examples

      iex> show_unread_notification_category(actor, "forum_post", pagination)
      {:ok, {:forum_post, %Scrivener.Page{}}}

      iex> show_unread_notification_category(actor, "unknown", pagination)
      {:error, :not_found}

  """
  @spec show_unread_notification_category(Actor.t(), any(), Repo.pagination_params()) ::
          {:ok, {category(), Scrivener.Page.t()}}
          | {:error, :not_found | :unauthorized}
  def show_unread_notification_category(%Actor{user: nil}, _param, _pagination),
    do: {:error, :unauthorized}

  def show_unread_notification_category(%Actor{user: %User{} = user}, param, pagination) do
    with {:ok, category} <- parse_category(param) do
      {:ok, {category, unread_page(category, user, pagination)}}
    end
  end

  @doc """
  Broadcasts a channel go-live event to the channel's subscribers.

  This write participates in the caller's ambient Repo transaction.
  The owning context is responsible for deciding that the event is authorized.

  ## Examples

      iex> broadcast_channel_live(channel)
      {:ok, 2}

  """
  @spec broadcast_channel_live(Channel.t()) :: count_result()
  def broadcast_channel_live(%Channel{} = channel) do
    broadcast_notification(
      from: {Channels.Subscription, channel_id: channel.id},
      into: ChannelLiveNotification,
      select: [channel_id: channel.id],
      unique_key: :channel_id
    )
  end

  @doc """
  Broadcasts a new post event to topic subscribers other than the author.

  This write participates in the caller's ambient Repo transaction.
  The owning context is responsible for authorizing the post.

  ## Examples

      iex> broadcast_forum_post(author, topic, post)
      {:ok, 2}

  """
  @spec broadcast_forum_post(User.t() | nil, Topic.t(), Post.t()) :: count_result()
  def broadcast_forum_post(author, %Topic{} = topic, %Post{} = post) do
    broadcast_notification(
      notification_author: author,
      from: {Topics.Subscription, topic_id: topic.id},
      into: ForumPostNotification,
      select: [topic_id: topic.id, post_id: post.id],
      unique_key: :topic_id
    )
  end

  @doc """
  Broadcasts a new topic event to forum subscribers other than the author.

  This write participates in the caller's ambient Repo transaction.
  The owning context is responsible for authorizing the topic.

  ## Examples

      iex> broadcast_forum_topic(author, topic)
      {:ok, 2}

  """
  @spec broadcast_forum_topic(User.t() | nil, Topic.t()) :: count_result()
  def broadcast_forum_topic(author, %Topic{} = topic) do
    broadcast_notification(
      notification_author: author,
      from: {Forums.Subscription, forum_id: topic.forum_id},
      into: ForumTopicNotification,
      select: [topic_id: topic.id],
      unique_key: :topic_id
    )
  end

  @doc """
  Broadcasts an images added event to gallery subscribers.

  This write participates in the caller's ambient Repo transaction.
  The owning context is responsible for authorizing the change.

  ## Examples

      iex> broadcast_gallery_image(gallery)
      {:ok, 2}

  """
  @spec broadcast_gallery_image(Gallery.t()) :: count_result()
  def broadcast_gallery_image(%Gallery{} = gallery) do
    broadcast_notification(
      from: {Galleries.Subscription, gallery_id: gallery.id},
      into: GalleryImageNotification,
      select: [gallery_id: gallery.id],
      unique_key: :gallery_id
    )
  end

  @doc """
  Broadcasts an image comment event to image subscribers other than the author.

  This write participates in the caller's ambient Repo transaction.
  The owning context is responsible for authorizing the comment.

  ## Examples

      iex> broadcast_image_comment(author, image, comment)
      {:ok, 2}

  """
  @spec broadcast_image_comment(User.t() | nil, Image.t(), Comment.t()) :: count_result()
  def broadcast_image_comment(author, %Image{} = image, %Comment{} = comment) do
    broadcast_notification(
      notification_author: author,
      from: {Images.Subscription, image_id: image.id},
      into: ImageCommentNotification,
      select: [image_id: image.id, comment_id: comment.id],
      unique_key: :image_id
    )
  end

  @doc """
  Broadcasts an image merge event to subscribers of the target image.

  This write participates in the caller's ambient Repo transaction.
  The owning context is responsible for authorizing the merge.

  ## Examples

      iex> broadcast_image_merge(target, source)
      {:ok, 2}

  """
  @spec broadcast_image_merge(Image.t(), Image.t()) :: count_result()
  def broadcast_image_merge(%Image{} = target, %Image{} = source) do
    broadcast_notification(
      from: {Images.Subscription, image_id: target.id},
      into: ImageMergeNotification,
      select: [target_id: target.id, source_id: source.id],
      unique_key: :target_id
    )
  end

  @doc """
  Clears `user`'s live notification for `channel`.

  The clear participates in the caller's ambient Repo transaction.
  Passing a `nil` user removes zero rows.

  ## Examples

      iex> clear_channel_live(channel, user)
      {:ok, 1}

      iex> clear_channel_live(channel, nil)
      {:ok, 0}

  """
  @spec clear_channel_live(Channel.t(), User.t() | nil) :: count_result()
  def clear_channel_live(%Channel{} = channel, user) do
    ChannelLiveNotification
    |> where(channel_id: ^channel.id)
    |> clear_for_user(user)
  end

  @doc """
  Clears `user`'s new-post notification for `topic`.

  The clear participates in the caller's ambient Repo transaction.
  Passing a `nil` user removes zero rows.

  ## Examples

      iex> clear_forum_post(topic, user)
      {:ok, 1}

  """
  @spec clear_forum_post(Topic.t(), User.t() | nil) :: count_result()
  def clear_forum_post(%Topic{} = topic, user) do
    ForumPostNotification
    |> where(topic_id: ^topic.id)
    |> clear_for_user(user)
  end

  @doc """
  Clears `user`'s new-topic notification for `topic`.

  The clear participates in the caller's ambient Repo transaction.
  Passing a `nil` user removes zero rows.

  ## Examples

      iex> clear_forum_topic(topic, user)
      {:ok, 1}

  """
  @spec clear_forum_topic(Topic.t(), User.t() | nil) :: count_result()
  def clear_forum_topic(%Topic{} = topic, user) do
    ForumTopicNotification
    |> where(topic_id: ^topic.id)
    |> clear_for_user(user)
  end

  @doc """
  Clears `user`'s image notification for `gallery`.

  The clear participates in the caller's ambient Repo transaction.
  Passing a `nil` user removes zero rows.

  ## Examples

      iex> clear_gallery_image(gallery, user)
      {:ok, 1}

  """
  @spec clear_gallery_image(Gallery.t(), User.t() | nil) :: count_result()
  def clear_gallery_image(%Gallery{} = gallery, user) do
    GalleryImageNotification
    |> where(gallery_id: ^gallery.id)
    |> clear_for_user(user)
  end

  @doc """
  Clears `user`'s comment notification for `image`.

  The clear participates in the caller's ambient Repo transaction.
  Passing a `nil` user removes zero rows.

  ## Examples

      iex> clear_image_comment(image, user)
      {:ok, 1}

  """
  @spec clear_image_comment(Image.t(), User.t() | nil) :: count_result()
  def clear_image_comment(%Image{} = image, user) do
    ImageCommentNotification
    |> where(image_id: ^image.id)
    |> clear_for_user(user)
  end

  @doc """
  Clears `user`'s merge notification for `image`.

  The clear participates in the caller's ambient Repo transaction.
  Passing a `nil` user removes zero rows.

  ## Examples

      iex> clear_image_merge(image, user)
      {:ok, 1}

  """
  @spec clear_image_merge(Image.t(), User.t() | nil) :: count_result()
  def clear_image_merge(%Image{} = image, user) do
    ImageMergeNotification
    |> where(target_id: ^image.id)
    |> clear_for_user(user)
  end

  @doc """
  Migrates image comment and image merge notifications to the target image.
  """
  @spec put_migrate_image_notifications(Multi.t(), Image.t(), Image.t()) :: Multi.t()
  def put_migrate_image_notifications(%Multi{} = multi, %Image{} = source, %Image{} = target) do
    Multi.run(multi, :migrate_image_notifications, fn repo, _changes ->
      comment_notifications =
        from notification in ImageCommentNotification,
          where: notification.image_id == ^source.id,
          select: %{
            user_id: notification.user_id,
            image_id: ^target.id,
            comment_id: notification.comment_id,
            read: notification.read,
            created_at: notification.created_at,
            updated_at: notification.updated_at
          }

      merge_notifications =
        from notification in ImageMergeNotification,
          where: notification.target_id == ^source.id,
          select: %{
            user_id: notification.user_id,
            target_id: ^target.id,
            source_id: notification.source_id,
            read: notification.read,
            created_at: notification.created_at,
            updated_at: notification.updated_at
          }

      {comment_count, nil} =
        repo.insert_all(ImageCommentNotification, comment_notifications, on_conflict: :nothing)

      {merge_count, nil} =
        repo.insert_all(ImageMergeNotification, merge_notifications, on_conflict: :nothing)

      repo.delete_all(exclude(comment_notifications, :select))
      repo.delete_all(exclude(merge_notifications, :select))

      {:ok, {comment_count, merge_count}}
    end)
  end
end
