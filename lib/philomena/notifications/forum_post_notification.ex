defmodule Philomena.Notifications.ForumPostNotification do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  alias Philomena.Topics.Topic
  alias Philomena.Posts.Post

  @primary_key false

  schema "forum_post_notifications" do
    belongs_to :user, User, primary_key: true
    belongs_to :topic, Topic, primary_key: true
    belongs_to :post, Post

    field :read, :boolean, default: false

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(forum_post_notification, attrs) do
    forum_post_notification
    |> cast(attrs, [])
    |> validate_required([])
  end
end
