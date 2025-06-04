defmodule Philomena.TagChanges.TagChange do
  use Ecto.Schema

  schema "tag_changes" do
    belongs_to :user, Philomena.Users.User
    belongs_to :image, Philomena.Images.Image
    has_many :tags, Philomena.TagChanges.Tag

    field :ip, EctoNetwork.INET
    field :fingerprint, :string

    timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
  end
end
