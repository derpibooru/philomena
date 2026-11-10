defmodule Philomena.TagChanges.TagChange do
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "tag_changes" do
    belongs_to :user, Philomena.Users.User
    belongs_to :image, Philomena.Images.Image
    has_many :tag_change_tags, Philomena.TagChanges.TagChangeTag

    field :ip, EctoNetwork.INET
    field :fingerprint, :string

    timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
  end
end
