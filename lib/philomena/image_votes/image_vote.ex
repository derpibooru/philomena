defmodule Philomena.ImageVotes.ImageVote do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Images.Image
  alias Philomena.Users.User

  @primary_key false

  schema "image_votes" do
    belongs_to :user, User, primary_key: true
    belongs_to :image, Image, primary_key: true
    field :up, :boolean
    timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
  end

  @doc false
  def changeset(image_vote, attrs) do
    image_vote
    |> cast(attrs, [])
    |> validate_required([])
  end
end
