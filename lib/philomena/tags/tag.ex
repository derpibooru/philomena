defmodule Philomena.Tags.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tags" do
    belongs_to :aliased_tag, Philomena.Tags.Tag, source: :aliased_tag_id
    has_many :aliases, Philomena.Tags.Tag, foreign_key: :aliased_tag_id

    field :slug, :string
    field :name, :string
    field :category, :string
    field :images_count, :integer
    field :description, :string
    field :short_description, :string

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [])
    |> validate_required([])
  end
end
