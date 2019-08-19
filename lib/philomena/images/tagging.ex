defmodule Philomena.Images.Tagging do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "image_taggings" do
    belongs_to :image, Philomena.Images.Image, primary_key: true
    belongs_to :tag, Philomena.Tags.Tag, primary_key: true
  end

  @doc false
  def changeset(tagging, attrs) do
    tagging
    |> cast(attrs, [])
    |> validate_required([])
  end
end
