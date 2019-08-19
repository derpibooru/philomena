defmodule Philomena.Galleries.Interaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gallery_interactions" do
    belongs_to :gallery, Philomena.Galleries.Gallery
    belongs_to :image, Philomena.Images.Image

    field :position, :integer
  end

  @doc false
  def changeset(interaction, attrs) do
    interaction
    |> cast(attrs, [])
    |> validate_required([])
  end
end
