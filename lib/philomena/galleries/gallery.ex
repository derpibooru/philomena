defmodule Philomena.Galleries.Gallery do
  use Ecto.Schema
  import Ecto.Changeset

  schema "galleries" do
    belongs_to :thumbnail, Philomena.Images.Image, source: :thumbnail_id
    belongs_to :creator, Philomena.Users.User, source: :creator_id

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
