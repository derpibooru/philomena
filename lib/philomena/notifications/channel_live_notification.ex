defmodule Philomena.Notifications.ChannelLiveNotification do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  alias Philomena.Channels.Channel

  @primary_key false

  schema "channel_live_notifications" do
    belongs_to :user, User, primary_key: true
    belongs_to :channel, Channel, primary_key: true

    field :read, :boolean, default: false

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(channel_live_notification, attrs) do
    channel_live_notification
    |> cast(attrs, [])
    |> validate_required([])
  end
end
