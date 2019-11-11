defmodule Philomena.Tags.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  use Philomena.Elasticsearch,
    definition: Philomena.Tags.Elasticsearch,
    index_name: "tags",
    doc_type: "tag"

  schema "tags" do
    belongs_to :aliased_tag, Philomena.Tags.Tag, source: :aliased_tag_id
    has_many :aliases, Philomena.Tags.Tag, foreign_key: :aliased_tag_id
    many_to_many :implied_tags, Philomena.Tags.Tag, join_through: "tags_implied_tags", join_keys: [tag_id: :id, implied_tag_id: :id]
    many_to_many :implied_by_tags, Philomena.Tags.Tag, join_through: "tags_implied_tags", join_keys: [implied_tag_id: :id, tag_id: :id]

    field :slug, :string
    field :name, :string
    field :category, :string
    field :images_count, :integer, default: 0
    field :description, :string
    field :short_description, :string
    field :namespace, :string
    field :name_in_namespace, :string
    field :image, :string
    field :image_format, :string
    field :image_mime_type, :string
    field :mod_notes, :string

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [])
    |> validate_required([])
  end

  def display_order do
    Philomena.Tags.Tag
    |> order_by(
      [t],
      asc: t.category == "spoiler",
      asc: t.category == "content-official",
      asc: t.category == "content-fanmade",
      asc: t.category == "species",
      asc: t.category == "oc",
      asc: t.category == "character",
      asc: t.category == "origin",
      asc: t.category == "rating",
      asc: t.name
    )
  end
end
