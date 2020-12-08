defmodule Philomena.Channels do
  @moduledoc """
  The Channels context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Channels.Channel
  alias Philomena.Channels.PicartoChannel
  alias Philomena.Channels.PiczelChannel
  alias Philomena.Notifications

  @doc """
  Updates all the tracked channels for which an update
  scheme is known.
  """
  def update_tracked_channels! do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    picarto_channels = PicartoChannel.live_channels(now)
    live_picarto_channels = Map.keys(picarto_channels)

    piczel_channels = PiczelChannel.live_channels(now)
    live_piczel_channels = Map.keys(piczel_channels)

    # Update all channels which are offline to reflect offline status
    offline_query =
      from c in Channel,
        where: c.type == "PicartoChannel" and c.short_name not in ^live_picarto_channels,
        or_where: c.type == "PiczelChannel" and c.short_name not in ^live_piczel_channels

    Repo.update_all(offline_query, set: [is_live: false, updated_at: now])

    # Update all channels which are online to reflect online status using
    # changeset functions
    online_query =
      from c in Channel,
        where: c.type == "PicartoChannel" and c.short_name in ^live_picarto_channels,
        or_where: c.type == "PiczelChannel" and c.short_name in ^live_picarto_channels

    online_query
    |> Repo.all()
    |> Enum.map(fn
      %{type: "PicartoChannel", short_name: name} = channel ->
        Channel.update_changeset(channel, Map.get(picarto_channels, name, []))

      %{type: "PiczelChannel", short_name: name} = channel ->
        Channel.update_changeset(channel, Map.get(piczel_channels, name, []))
    end)
    |> Enum.map(&Repo.update!/1)
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
