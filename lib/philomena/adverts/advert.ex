defmodule Philomena.Adverts.Advert do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Schema.Time

  schema "adverts" do
    field :image, :string
    field :link, :string
    field :title, :string
    field :clicks, :integer, default: 0
    field :impressions, :integer, default: 0
    field :live, :boolean, default: false
    field :start_date, :utc_datetime
    field :finish_date, :utc_datetime
    field :restrictions, :string
    field :notes, :string

    field :image_mime_type, :string, virtual: true
    field :image_size, :integer, virtual: true
    field :image_width, :integer, virtual: true
    field :image_height, :integer, virtual: true

    field :uploaded_image, :string, virtual: true
    field :removed_image, :string, virtual: true

    field :start_time, :string, virtual: true
    field :finish_time, :string, virtual: true

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(advert, attrs) do
    advert
    |> cast(attrs, [])
    |> Time.propagate_time(:start_date, :start_time)
    |> Time.propagate_time(:finish_date, :finish_time)
  end

  def save_changeset(advert, attrs) do
    advert
    |> cast(attrs, [:title, :link, :start_time, :finish_time, :live, :restrictions, :notes])
    |> Time.assign_time(:start_time, :start_date)
    |> Time.assign_time(:finish_time, :finish_date)
    |> validate_required([:title, :link, :start_date, :finish_date])
    |> validate_inclusion(:restrictions, ["none", "nsfw", "sfw"])
  end

  def image_changeset(advert, attrs) do
    advert
    |> cast(attrs, [
      :image,
      :image_mime_type,
      :image_size,
      :image_width,
      :image_height,
      :uploaded_image,
      :removed_image
    ])
    |> validate_required([:image])
    |> validate_inclusion(:image_mime_type, ["image/png", "image/jpeg", "image/gif"])
    |> validate_inclusion(:image_width, 699..729)
    |> validate_inclusion(:image_height, 79..91)
    |> validate_inclusion(:image_size, 0..750_000)
  end
end
