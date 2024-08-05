defmodule Philomena.Notifications.ImageMergeNotification do
  use Ecto.Schema

  alias Philomena.Users.User
  alias Philomena.Images.Image

  @primary_key false

  schema "image_merge_notifications" do
    belongs_to :user, User, primary_key: true
    belongs_to :target, Image, primary_key: true
    belongs_to :source, Image

    field :read, :boolean, default: false

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end
end
