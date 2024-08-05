defmodule Philomena.Notifications.ImageCommentNotification do
  use Ecto.Schema

  alias Philomena.Users.User
  alias Philomena.Images.Image
  alias Philomena.Comments.Comment

  @primary_key false

  schema "image_comment_notifications" do
    belongs_to :user, User, primary_key: true
    belongs_to :image, Image, primary_key: true
    belongs_to :comment, Comment

    field :read, :boolean, default: false

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end
end
