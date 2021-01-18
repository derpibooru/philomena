defmodule Philomena.ImageFeatures.ImageFeature do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Images.Image
  alias Philomena.Users.User

  @primary_key false

  schema "image_features" do
    belongs_to :image, Image
    belongs_to :user, User

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(image_feature, attrs) do
    image_feature
    |> cast(attrs, [])
    |> validate_required([])
  end
end
