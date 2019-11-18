defmodule Philomena.Galleries.Gallery do
  use Ecto.Schema
  import Ecto.Changeset

  use Philomena.Elasticsearch,
    definition: Philomena.Galleries.Elasticsearch,
    index_name: "galleries",
    doc_type: "gallery"

  alias Philomena.Images.Image
  alias Philomena.Users.User

  schema "galleries" do
    belongs_to :thumbnail, Image, source: :thumbnail_id
    belongs_to :creator, User, source: :creator_id

    field :title, :string
    field :spoiler_warning, :string
    field :description, :string
    field :image_count, :integer
    field :order_position_asc, :boolean

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(gallery, attrs) do
    gallery
    |> cast(attrs, [])
    |> validate_required([])
  end
end
