defmodule Philomena.Channels.Channel do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Tags.Tag
  alias Philomena.Repo

  schema "channels" do
    belongs_to :associated_artist_tag, Tag

    # fixme: rails STI
    field :type, :string

    field :short_name, :string
    field :title, :string, default: ""
    field :description, :string
    field :tags, :string
    field :viewers, :integer, default: 0
    field :nsfw, :boolean, default: false
    field :is_live, :boolean, default: false
    field :last_fetched_at, :utc_datetime
    field :next_check_at, :utc_datetime
    field :last_live_at, :utc_datetime

    field :viewer_minutes_today, :integer, default: 0
    field :viewer_minutes_thisweek, :integer, default: 0
    field :viewer_minutes_thismonth, :integer, default: 0
    field :total_viewer_minutes, :integer, default: 0

    field :banner_image, :string
    field :channel_image, :string
    field :remote_stream_id, :integer
    field :thumbnail_url, :string, default: ""

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(channel, attrs) do
    tag_id =
      if attrs["artist_tag"] do
        Repo.get_by(Tag, name: attrs["artist_tag"]).id
      else
        nil
      end

    channel
    |> cast(attrs, [:type, :short_name])
    |> validate_required([:type, :short_name])
    |> validate_inclusion(:type, ["PicartoChannel", "PiczelChannel"])
    |> put_change(:associated_artist_tag_id, tag_id)
  end
end
