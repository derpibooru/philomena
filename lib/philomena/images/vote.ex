defmodule Philomena.Images.Vote do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "image_votes" do
    belongs_to :user, Philomena.Users.User, primary_key: true
    belongs_to :image, Philomena.Images.Image, primary_key: true
    field :up, :boolean
    timestamps(inserted_at: :created_at, updated_at: false)
  end

  @doc false
  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [])
    |> validate_required([])
  end
end
