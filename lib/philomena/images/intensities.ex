defmodule Philomena.Images.Intensities do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "image_intensities" do
    belongs_to :image, Philomena.Images.Image, primary_key: true

    field :nw, :float
    field :ne, :float
    field :sw, :float
    field :se, :float
  end

  @doc false
  def changeset(intensities, attrs) do
    intensities
    |> cast(attrs, [])
    |> validate_required([])
  end
end
