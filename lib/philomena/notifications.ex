defmodule Philomena.Notifications do
  @moduledoc """
  The Notifications context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Notifications.Category
  alias Philomena.Notifications.Notification
  alias Philomena.Notifications.UnreadNotification
  alias Philomena.Polymorphic

  @doc """
  Returns the list of unread notifications of the given type.

  The set of valid types is `t:Philomena.Notifications.Category.t/0`.

  ## Examples

      iex> unread_notifications_for_user_and_type(user, :image_comment, ...)
      [%Notification{}, ...]

  """
  def unread_notifications_for_user_and_type(user, type, pagination) do
    notifications =
      user
      |> unread_query_for_type(type)
      |> Repo.paginate(pagination)

    put_in(notifications.entries, load_associations(notifications.entries))
  end

  @doc """
  Gather up and return the top N notifications for the user, for each type of
  unread notification currently existing.

  ## Examples

      iex> unread_notifications_for_user(user)
      [
        forum_topic: [%Notification{...}, ...],
        forum_post: [%Notification{...}, ...],
        image_comment: [%Notification{...}, ...]
      ]

  """
  def unread_notifications_for_user(user, n) do
    Category.types()
    |> Enum.map(fn type ->
      q =
        user
        |> unread_query_for_type(type)
        |> limit(^n)

      # Use a subquery to ensure the order by is applied to the
      # subquery results only, and not the main query results
      from(n in subquery(q))
    end)
    |> union_all_queries()
    |> Repo.all()
    |> load_associations()
    |> Enum.group_by(&Category.notification_type/1)
    |> Enum.sort_by(fn {k, _v} -> k end)
  end

  defp unread_query_for_type(user, type) do
    from n in Category.query_for_type(type),
      join: un in UnreadNotification,
      on: un.notification_id == n.id,
      where: un.user_id == ^user.id,
      order_by: [desc: :updated_at]
  end

  defp union_all_queries([query | rest]) do
    Enum.reduce(rest, query, fn q, acc -> union_all(acc, ^q) end)
  end

  defp load_associations(notifications) do
    Polymorphic.load_polymorphic(
      notifications,
      actor: [actor_id: :actor_type],
      actor_child: [actor_child_id: :actor_child_type]
    )
  end

  @doc """
  Gets a single notification.

  Raises `Ecto.NoResultsError` if the Notification does not exist.

  ## Examples

      iex> get_notification!(123)
      %Notification{}

      iex> get_notification!(456)
      ** (Ecto.NoResultsError)

  """
  def get_notification!(id), do: Repo.get!(Notification, id)

  @doc """
  Creates a notification.

  ## Examples

      iex> create_notification(%{field: value})
      {:ok, %Notification{}}

      iex> create_notification(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_notification(attrs \\ %{}) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a notification.

  ## Examples

      iex> update_notification(notification, %{field: new_value})
      {:ok, %Notification{}}

      iex> update_notification(notification, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_notification(%Notification{} = notification, attrs) do
    notification
    |> Notification.changeset(attrs)
    |> Repo.insert_or_update()
  end

  @doc """
  Deletes a Notification.

  ## Examples

      iex> delete_notification(notification)
      {:ok, %Notification{}}

      iex> delete_notification(notification)
      {:error, %Ecto.Changeset{}}

  """
  def delete_notification(%Notification{} = notification) do
    Repo.delete(notification)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking notification changes.

  ## Examples

      iex> change_notification(notification)
      %Ecto.Changeset{source: %Notification{}}

  """
  def change_notification(%Notification{} = notification) do
    Notification.changeset(notification, %{})
  end

  def count_unread_notifications(user) do
    UnreadNotification
    |> where(user_id: ^user.id)
    |> Repo.aggregate(:count, :notification_id)
  end

  @doc """
  Creates a unread_notification.

  ## Examples

      iex> create_unread_notification(%{field: value})
      {:ok, %UnreadNotification{}}

      iex> create_unread_notification(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_unread_notification(attrs \\ %{}) do
    %UnreadNotification{}
    |> UnreadNotification.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a unread_notification.

  ## Examples

      iex> update_unread_notification(unread_notification, %{field: new_value})
      {:ok, %UnreadNotification{}}

      iex> update_unread_notification(unread_notification, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_unread_notification(%UnreadNotification{} = unread_notification, attrs) do
    unread_notification
    |> UnreadNotification.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a UnreadNotification.

  ## Examples

      iex> delete_unread_notification(unread_notification)
      {:ok, %UnreadNotification{}}

      iex> delete_unread_notification(unread_notification)
      {:error, %Ecto.Changeset{}}

  """
  def delete_unread_notification(actor_type, actor_id, user) do
    notification =
      Notification
      |> where(actor_type: ^actor_type, actor_id: ^actor_id)
      |> Repo.one()

    if notification do
      UnreadNotification
      |> where(notification_id: ^notification.id, user_id: ^user.id)
      |> Repo.delete_all()
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking unread_notification changes.

  ## Examples

      iex> change_unread_notification(unread_notification)
      %Ecto.Changeset{source: %UnreadNotification{}}

  """
  def change_unread_notification(%UnreadNotification{} = unread_notification) do
    UnreadNotification.changeset(unread_notification, %{})
  end

  def notify(_actor_child, [], _params), do: nil

  def notify(actor_child, subscriptions, params) do
    # Don't push to the user that created the notification
    subscriptions =
      case actor_child do
        %{user_id: id} ->
          subscriptions
          |> Enum.reject(&(&1.user_id == id))

        _ ->
          subscriptions
      end

    Repo.transaction(fn ->
      notification =
        Notification
        |> Repo.get_by(actor_id: params.actor_id, actor_type: params.actor_type)

      {:ok, notification} =
        (notification || %Notification{})
        |> update_notification(params)

      # Insert the notification to any watchers who do not have it
      unreads =
        subscriptions
        |> Enum.map(&%{user_id: &1.user_id, notification_id: notification.id})

      UnreadNotification
      |> Repo.insert_all(unreads, on_conflict: :nothing)
    end)
  end
end
