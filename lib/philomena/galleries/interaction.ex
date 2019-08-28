defmodule Philomena.Galleries.Interaction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "gallery_interactions" do
    belongs_to :gallery, Philomena.Galleries.Gallery, primary_key: true
    belongs_to :image, Philomena.Images.Image, primary_key: true

    field :position, :integer
  end

  @doc false
  def changeset(interaction, attrs) do
    interaction
    |> cast(attrs, [])
    |> validate_required([])
  end
end
