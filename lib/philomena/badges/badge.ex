defmodule Philomena.Badges.Badge do
  use Ecto.Schema
  import Ecto.Changeset

  schema "badges" do
    field :title, :string
    field :description, :string, default: ""
    field :image, :string
    field :disable_award, :boolean, default: false
    field :priority, :boolean, default: false

    field :uploaded_image, :string, virtual: true
    field :removed_image, :string, virtual: true
    field :image_mime_type, :string, virtual: true

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(badge, attrs) do
    badge
    |> cast(attrs, [:title, :description, :disable_award, :priority])
    |> validate_required([:title])
    |> validate_length(:description, max: 1000, count: :bytes)
  end

  def image_changeset(badge, attrs) do
    badge
    |> cast(attrs, [:image, :image_mime_type, :uploaded_image, :removed_image])
    |> validate_required([:image, :image_mime_type])
    |> validate_inclusion(:image_mime_type, ["image/svg+xml"])
  end
end
