defmodule Philomena.Channels.Channel do
  use Ecto.Schema
  import Ecto.Changeset

  schema "channels" do
    belongs_to :associated_artist_tag, Philomena.Tags.Tag

    # fixme: rails STI
    field :type, :string

    field :short_name, :string
    field :title, :string
    field :description, :string
    field :tags, :string
    field :viewers, :integer, default: 0
    field :nsfw, :boolean, default: false
    field :is_live, :boolean, default: false
    field :last_fetched_at, :naive_datetime
    field :next_check_at, :naive_datetime
    field :last_live_at, :naive_datetime

    field :viewer_minutes_today, :integer, default: 0
    field :viewer_minutes_thisweek, :integer, default: 0
    field :viewer_minutes_thismonth, :integer, default: 0
    field :total_viewer_minutes, :integer, default: 0

    field :banner_image, :string
    field :channel_image, :string
    field :remote_stream_id, :integer
    field :thumbnail_url, :string, default: ""
  end

  @doc false
  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [])
    |> validate_required([])
  end
end
