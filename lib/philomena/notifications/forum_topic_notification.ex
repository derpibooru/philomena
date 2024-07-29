defmodule Philomena.Notifications.ForumTopicNotification do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  alias Philomena.Topics.Topic

  @primary_key false

  schema "forum_topic_notifications" do
    belongs_to :user, User, primary_key: true
    belongs_to :topic, Topic, primary_key: true

    field :read, :boolean, default: false

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(forum_topic_notification, attrs) do
    forum_topic_notification
    |> cast(attrs, [])
    |> validate_required([])
  end
end
