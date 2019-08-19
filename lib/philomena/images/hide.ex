defmodule Philomena.Images.Hide do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "image_hides" do
    belongs_to :user, Philomena.Users.User, primary_key: true
    belongs_to :image, Philomena.Images.Image, primary_key: true
    timestamps(inserted_at: :created_at, updated_at: false)
  end

  @doc false
  def changeset(hide, attrs) do
    hide
    |> cast(attrs, [])
    |> validate_required([])
  end
end
