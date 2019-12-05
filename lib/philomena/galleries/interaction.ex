defmodule Philomena.Galleries.Interaction do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Galleries.Gallery
  alias Philomena.Images.Image

  @primary_key false

  schema "gallery_interactions" do
    belongs_to :gallery, Gallery, primary_key: true
    belongs_to :image, Image, primary_key: true

    field :position, :integer
  end

  @doc false
  def changeset(interaction, attrs) do
    interaction
    |> cast(attrs, [:image_id, :position])
    |> validate_required([:image_id, :position])
    |> foreign_key_constraint(:image_id, name: :fk_rails_bb5ebe2a77)
    |> case do
      %{valid?: false, changes: changes} = changeset when changes == %{} ->
        %{changeset | action: :ignore}

      changeset ->
        changeset
    end
  end
end
