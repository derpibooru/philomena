defmodule Philomena.ImageFaves.ImageFave do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Images.Image
  alias Philomena.Users.User

  @primary_key false

  schema "image_faves" do
    belongs_to :user, User, primary_key: true
    belongs_to :image, Image, primary_key: true
    timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
  end

  @doc false
  def changeset(image_fave, attrs) do
    image_fave
    |> cast(attrs, [])
    |> validate_required([])
    |> unique_constraint([:image_id, :user_id], name: :index_image_faves_on_image_id_and_user_id)
  end
end
