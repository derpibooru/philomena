defmodule Philomena.Notifications.GalleryImageNotification do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  alias Philomena.Galleries.Gallery

  @primary_key false

  schema "gallery_image_notifications" do
    belongs_to :user, User, primary_key: true
    belongs_to :gallery, Gallery, primary_key: true

    field :read, :boolean, default: false

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(gallery_image_notification, attrs) do
    gallery_image_notification
    |> cast(attrs, [])
    |> validate_required([])
  end
end
