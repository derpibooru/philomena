defmodule Philomena.Notifications.Creator do
  @moduledoc """
  Internal notifications creation logic.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  @doc """
  Propagate notifications for a notification table type.

  Returns `{:ok, count}`, where `count` is the number of affected rows.

  ## Examples

      iex> broadcast_notification(
      ...>   from: {GallerySubscription, gallery_id: gallery.id},
      ...>   into: GalleryImageNotification,
      ...>   select: [gallery_id: gallery.id],
      ...>   unique_key: :gallery_id
      ...> )
      {:ok, 2}

      iex> broadcast_notification(
      ...>   notification_author: user,
      ...>   from: {ImageSubscription, image_id: image.id},
      ...>   into: ImageCommentNotification,
      ...>   select: [image_id: image.id, comment_id: comment.id],
      ...>   unique_key: :image_id
      ...> )
      {:ok, 2}

  """
  def broadcast_notification(opts) do
    opts = Keyword.validate!(opts, [:notification_author, :from, :into, :select, :unique_key])

    notification_author = Keyword.get(opts, :notification_author, nil)
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

  # TODO: the following cannot be accomplished with a single query expression
  # due to this Ecto bug: https://github.com/elixir-ecto/ecto/issues/4430

  defp convert_to_notification(subscription, [{name, object_id}]) do
    now = DateTime.utc_now(:second)

    from s in subscription,
      select: %{
        ^name => type(^object_id, :integer),
        user_id: s.user_id,
        created_at: ^now,
        updated_at: ^now,
        read: false
      }
  end

  defp convert_to_notification(subscription, [{name1, object_id1}, {name2, object_id2}]) do
    now = DateTime.utc_now(:second)

    from s in subscription,
      select: %{
        ^name1 => type(^object_id1, :integer),
        ^name2 => type(^object_id2, :integer),
        user_id: s.user_id,
        created_at: ^now,
        updated_at: ^now,
        read: false
      }
  end

  defp subscription_query(subscription, notification_author) do
    case notification_author do
      %{id: user_id} ->
        # Avoid sending notifications to the user which performed the action.
        from s in subscription,
          where: s.user_id != ^user_id

      _ ->
        # When not created by a user, send notifications to all subscribers.
        subscription
    end
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
end
