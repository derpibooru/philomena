defmodule Philomena.ImageIntensities.ImageIntensity do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Images.Image

  @primary_key false

  schema "image_intensities" do
    belongs_to :image, Image, primary_key: true

    field :nw, :float
    field :ne, :float
    field :sw, :float
    field :se, :float
  end

  @doc false
  def changeset(image_intensity, attrs) do
    image_intensity
    |> cast(attrs, [:nw, :ne, :sw, :se])
    |> validate_required([:image_id, :nw, :ne, :sw, :se])
    |> unique_constraint(:image_id, name: :index_image_intensities_on_image_id)
  end
end
