defmodule Philomena.ImageFeatures.ImageFeature do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Images.Image
  alias Philomena.Users.User

  @primary_key false

  @type t :: %__MODULE__{}

  schema "image_features" do
    belongs_to :image, Image
    belongs_to :user, User

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(image_feature, attrs \\ %{}) do
    image_feature
    |> cast(attrs, [])
    |> validate_required([])
  end

  @doc false
  def feature_changeset(image_feature, %Image{hidden_from_users: hidden_from_users}) do
    changeset = change(image_feature)

    if hidden_from_users do
      add_error(changeset, :image, "cannot be a deleted image")
    else
      changeset
    end
  end
end
