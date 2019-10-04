defmodule Philomena.Images.Feature do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "image_features" do
    belongs_to :image, Philomena.Images.Image
    belongs_to :user, Philomena.Users.User

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(features, attrs) do
    features
    |> cast(attrs, [])
    |> validate_required([])
  end
end
