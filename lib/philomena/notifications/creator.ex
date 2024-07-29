defmodule Philomena.Notifications.Creator do
  @moduledoc """
  Internal notifications creation logic.

  Supports two formats for notification creation:
  - Key-only (`create_single/4`): The object's id is the only other component inserted.
  - Non-key (`create_double/6`): The object's id plus another object's id are inserted.

  See the respective documentation for each function for more details.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  @doc """
  Propagate notifications for a notification table type containing a single reference column.

  The single reference column (`name`, `object`) is also part of the unique key for the table,
  and is used to select which object to act on.

  Returns `{:ok, count}`, where `count` is the number of affected rows.

  ## Example

      iex> create_single(GallerySubscription, GalleryImageNotification, nil, :gallery_id, gallery)
      {:ok, 2}

  """
  def create_single(subscription, notification, user, name, object) do
    subscription
    |> create_notification_query(user, name, object)
    |> create_notification(notification, name)
  end

  @doc """
  Propagate notifications for a notification table type containing two reference columns.

  The first reference column (`name1`, `object1`) is also part of the unique key for the table,
  and is used to select which object to act on.

  Returns `{:ok, count}`, where `count` is the number of affected rows.

  ## Example

      iex> create_double(
      ...>   ImageSubscription,
      ...>   ImageCommentNotification,
      ...>   user,
      ...>   :image_id,
      ...>   image,
      ...>   :comment_id,
      ...>   comment
      ...> )
      {:ok, 2}

  """
  def create_double(subscription, notification, user, name1, object1, name2, object2) do
    subscription
    |> create_notification_query(user, name1, object1, name2, object2)
    |> create_notification(notification, name1)
  end

  @doc """
  Clear all unread notifications using the given query.

  Returns `{:ok, count}`, where `count` is the number of affected rows.
  """
  def clear(query, user) do
    if user do
      {count, nil} =
        query
        |> where(user_id: ^user.id)
        |> Repo.delete_all()

      {:ok, count}
    else
      {:ok, 0}
    end
  end

  # TODO: the following cannot be accomplished with a single query expression
  # due to this Ecto bug: https://github.com/elixir-ecto/ecto/issues/4430

  defp create_notification_query(subscription, user, name, object) do
    now = DateTime.utc_now(:second)

    from s in subscription_query(subscription, user),
      where: field(s, ^name) == ^object.id,
      select: %{
        ^name => type(^object.id, :integer),
        user_id: s.user_id,
        created_at: ^now,
        updated_at: ^now,
        read: false
      }
  end

  defp create_notification_query(subscription, user, name1, object1, name2, object2) do
    now = DateTime.utc_now(:second)

    from s in subscription_query(subscription, user),
      where: field(s, ^name1) == ^object1.id,
      select: %{
        ^name1 => type(^object1.id, :integer),
        ^name2 => type(^object2.id, :integer),
        user_id: s.user_id,
        created_at: ^now,
        updated_at: ^now,
        read: false
      }
  end

  defp subscription_query(subscription, user) do
    case user do
      %{id: user_id} ->
        # Avoid sending notifications to the user which performed the action.
        from s in subscription,
          where: s.user_id != ^user_id

      _ ->
        # When not created by a user, send notifications to all subscribers.
        subscription
    end
  end

  defp create_notification(query, notification, name) do
    {count, nil} =
      Repo.insert_all(
        notification,
        query,
        on_conflict: {:replace_all_except, [:created_at]},
        conflict_target: [name, :user_id]
      )

    {:ok, count}
  end
end
