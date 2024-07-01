defmodule Philomena.Channels do
  @moduledoc """
  The Channels context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Channels.AutomaticUpdater
  alias Philomena.Channels.Channel
  alias Philomena.Notifications

  @doc """
  Updates all the tracked channels for which an update scheme is known.
  """
  def update_tracked_channels! do
    AutomaticUpdater.update_tracked_channels!()
  end

  @doc """
  Gets a single channel.

  Raises `Ecto.NoResultsError` if the Channel does not exist.

  ## Examples

      iex> get_channel!(123)
      %Channel{}

      iex> get_channel!(456)
      ** (Ecto.NoResultsError)

  """
  def get_channel!(id), do: Repo.get!(Channel, id)

  @doc """
  Creates a channel.

  ## Examples

      iex> create_channel(%{field: value})
      {:ok, %Channel{}}

      iex> create_channel(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_channel(attrs \\ %{}) do
    %Channel{}
    |> Channel.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a channel.

  ## Examples

      iex> update_channel(channel, %{field: new_value})
      {:ok, %Channel{}}

      iex> update_channel(channel, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_channel(%Channel{} = channel, attrs) do
    channel
    |> Channel.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates a channel's state when it goes live.

  ## Examples

      iex> update_channel_state(channel, %{field: new_value})
      {:ok, %Channel{}}

      iex> update_channel_state(channel, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_channel_state(%Channel{} = channel, attrs) do
    channel
    |> Channel.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Channel.

  ## Examples

      iex> delete_channel(channel)
      {:ok, %Channel{}}

      iex> delete_channel(channel)
      {:error, %Ecto.Changeset{}}

  """
  def delete_channel(%Channel{} = channel) do
    Repo.delete(channel)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking channel changes.

  ## Examples

      iex> change_channel(channel)
      %Ecto.Changeset{source: %Channel{}}

  """
  def change_channel(%Channel{} = channel) do
    Channel.changeset(channel, %{})
  end

  alias Philomena.Channels.Subscription

  @doc """
  Creates a subscription.

  ## Examples

      iex> create_subscription(%{field: value})
      {:ok, %Subscription{}}

      iex> create_subscription(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_subscription(_channel, nil), do: {:ok, nil}

  def create_subscription(channel, user) do
    %Subscription{channel_id: channel.id, user_id: user.id}
    |> Subscription.changeset(%{})
    |> Repo.insert(on_conflict: :nothing)
  end

  @doc """
  Deletes a Subscription.

  ## Examples

      iex> delete_subscription(subscription)
      {:ok, %Subscription{}}

      iex> delete_subscription(subscription)
      {:error, %Ecto.Changeset{}}

  """
  def delete_subscription(channel, user) do
    clear_notification(channel, user)

    %Subscription{channel_id: channel.id, user_id: user.id}
    |> Repo.delete()
  end

  def subscribed?(_channel, nil), do: false

  def subscribed?(channel, user) do
    Subscription
    |> where(channel_id: ^channel.id, user_id: ^user.id)
    |> Repo.exists?()
  end

  def subscriptions(_channels, nil), do: %{}

  def subscriptions(channels, user) do
    channel_ids = Enum.map(channels, & &1.id)

    Subscription
    |> where([s], s.channel_id in ^channel_ids and s.user_id == ^user.id)
    |> Repo.all()
    |> Map.new(&{&1.channel_id, true})
  end

  def clear_notification(channel, user) do
    Notifications.delete_unread_notification("Channel", channel.id, user)
    Notifications.delete_unread_notification("LivestreamChannel", channel.id, user)
  end
end
