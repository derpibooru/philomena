defmodule Philomena.Channels.Channel do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Tags.Tag

  schema "channels" do
    belongs_to :associated_artist_tag, Tag

    # fixme: rails STI
    field :type, :string

    field :short_name, :string
    field :title, :string, default: ""
    field :viewers, :integer, default: 0
    field :nsfw, :boolean, default: false
    field :is_live, :boolean, default: false
    field :last_fetched_at, :utc_datetime
    field :next_check_at, :utc_datetime
    field :last_live_at, :utc_datetime
    field :thumbnail_url, :string, default: ""

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:type, :short_name])
    |> validate_required([:type, :short_name])
    |> validate_inclusion(:type, ["PicartoChannel", "PiczelChannel"])
  end

  @doc false
  def update_changeset(channel, attrs) do
    cast(channel, attrs, [
      :title,
      :is_live,
      :nsfw,
      :viewers,
      :thumbnail_url,
      :last_fetched_at,
      :last_live_at
    ])
  end

  @doc false
  def artist_tag_changeset(channel, tag) do
    tag_id = Map.get(tag || %{}, :id)

    change(channel, associated_artist_tag_id: tag_id)
  end
end
