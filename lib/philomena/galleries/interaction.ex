defmodule Philomena.Galleries.Interaction do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Galleries.Gallery
  alias Philomena.Images.Image

  # fixme: unique-key this off (gallery_id, image_id)
  schema "gallery_interactions" do
    belongs_to :gallery, Gallery
    belongs_to :image, Image

    field :position, :integer
  end

  @doc false
  def changeset(interaction, attrs) do
    interaction
    |> cast(attrs, [:image_id, :position])
    |> validate_required([:image_id, :position])
    |> foreign_key_constraint(:image_id, name: :fk_rails_bb5ebe2a77)
    |> unique_constraint(:image_id, name: :index_gallery_interactions_on_gallery_id_and_image_id)
    |> case do
      %{valid?: false, changes: changes} = changeset when changes == %{} ->
        %{changeset | action: :ignore}

      changeset ->
        changeset
    end
  end
end
