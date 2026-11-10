defmodule Philomena.ChannelsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Channels` context.
  """

  import Philomena.AttributionFixtures, only: [actor: 1]
  import Philomena.UsersFixtures, only: [moderator_user_fixture: 0]

  alias Philomena.Channels

  def unique_channel_short_name, do: "test_channel_#{System.unique_integer([:positive])}"

  @doc """
  Creates a channel.

  Attrs are string-keyed the way the admin channel controller submits them;
  pass `"artist_tag" => tag.name` to associate an existing artist tag.
  """
  def channel_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        "type" => "PicartoChannel",
        "short_name" => unique_channel_short_name()
      })

    {:ok, channel} = Channels.create_channel(actor(moderator_user_fixture()), attrs)

    channel
  end

  @doc """
  Creates a channel the fetcher has stamped, so it appears on the livestreams
  index (`Channels.load_channels/4` lists only channels with `last_fetched_at`
  set).

  `create_attrs` are string-keyed the way the admin channel controller submits
  them (`"type"`, `"short_name"`, `"artist_tag"`). `state_attrs` are the atom-keyed
  fetcher-managed fields (`:title`, `:is_live`, `:nsfw`, `:viewers`,
  `:thumbnail_url`, `:last_fetched_at`); `:last_fetched_at` defaults to now.
  """
  def listed_channel_fixture(create_attrs \\ %{}, state_attrs \\ %{}) do
    state_attrs = Enum.into(state_attrs, %{last_fetched_at: DateTime.utc_now(:second)})

    {:ok, channel} =
      create_attrs
      |> channel_fixture()
      |> Channels.update_fetch_state(state_attrs)

    channel
  end
end
