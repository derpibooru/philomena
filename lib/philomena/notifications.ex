defmodule Philomena.Notifications do
  @moduledoc """
  The Notifications context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Notifications.Notification

  @doc """
  Returns the list of notifications.

  ## Examples

      iex> list_notifications()
      [%Notification{}, ...]

  """
  def list_notifications do
    Repo.all(Notification)
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

  alias Philomena.Notifications.UnreadNotification

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
          |> Enum.reject(& &1.user_id == id)

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
