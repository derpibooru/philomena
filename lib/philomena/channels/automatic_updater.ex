defmodule Philomena.Channels.AutomaticUpdater do
  @moduledoc """
  Automatic update routine for streams.

  Calls APIs for each stream provider to remove channels which are no longer online,
  and to restore channels which are currently online.
  """

  import Ecto.Query, warn: false

  alias Philomena.Channels
  alias Philomena.Channels.Channel
  alias Philomena.Channels.PicartoChannel
  alias Philomena.Channels.PiczelChannel
  alias Philomena.Repo

  @doc """
  Updates all the tracked channels for which an update scheme is known.
  """
  @spec update_tracked_channels!() :: :ok
  def update_tracked_channels! do
    now = DateTime.utc_now(:second)
    Enum.each(providers(), &update_provider(&1, now))
  end

  defp providers do
    [
      {"PicartoChannel", PicartoChannel.live_channels()},
      {"PiczelChannel", PiczelChannel.live_channels()}
    ]
  end

  defp update_provider({provider_name, live_channels}, now) do
    channel_names = Map.keys(live_channels)

    Channels.mark_provider_channels_offline(provider_name, channel_names, now)

    provider_name
    |> online_query(channel_names)
    |> Repo.all()
    |> Enum.each(&update_online_channel(&1, live_channels, now))
  end

  defp online_query(provider_name, channel_names) do
    from c in Channel,
      where: c.type == ^provider_name and c.short_name in ^channel_names
  end

  defp update_online_channel(channel, live_channels, now) do
    attrs =
      live_channels
      |> Map.get(channel.short_name, %{})
      |> Map.merge(%{last_fetched_at: now})

    Channels.update_fetch_state(channel, attrs)
  end
end
