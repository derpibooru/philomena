defmodule Philomena.Channels.Channel do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Tags.Tag

  @type t :: %__MODULE__{}

  schema "channels" do
    belongs_to :associated_artist_tag, Tag

    # Provider modules are selected from this legacy Rails STI discriminator.
    field :type, :string

    field :short_name, :string
    field :title, :string, default: ""
    field :viewers, :integer, default: 0
    field :nsfw, :boolean, default: false
    field :is_live, :boolean, default: false
    field :last_fetched_at, :utc_datetime
    field :thumbnail_url, :string, default: ""

    field :artist_tag, :string, virtual: true

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(channel, attrs \\ %{}) do
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
      :last_fetched_at
    ])
  end

  @doc false
  def artist_tag_name_changeset(channel, attrs) do
    channel
    |> cast(attrs, [:artist_tag])
    |> update_change(:artist_tag, &Tag.clean_tag_name/1)
  end

  @doc false
  def artist_tag_changeset(changeset, name, tag) do
    if not is_nil(name) and is_nil(tag) do
      add_error(changeset, :artist_tag, "is invalid")
    else
      put_change(changeset, :associated_artist_tag, tag)
    end
  end
end
