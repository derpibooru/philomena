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
    |> Repo.update()
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

  @doc """
  Returns the list of unread_notifications.

  ## Examples

      iex> list_unread_notifications()
      [%UnreadNotification{}, ...]

  """
  def list_unread_notifications do
    Repo.all(UnreadNotification)
  end

  @doc """
  Gets a single unread_notification.

  Raises `Ecto.NoResultsError` if the Unread notification does not exist.

  ## Examples

      iex> get_unread_notification!(123)
      %UnreadNotification{}

      iex> get_unread_notification!(456)
      ** (Ecto.NoResultsError)

  """
  def get_unread_notification!(id), do: Repo.get!(UnreadNotification, id)

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
  def delete_unread_notification(%UnreadNotification{} = unread_notification) do
    Repo.delete(unread_notification)
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
end
