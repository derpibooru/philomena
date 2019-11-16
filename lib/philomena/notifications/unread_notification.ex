defmodule Philomena.Notifications.UnreadNotification do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  alias Philomena.Notifications.Notification

  @primary_key false

  schema "unread_notifications" do
    belongs_to :user, User, primary_key: true
    belongs_to :notification, Notification, primary_key: true
  end

  @doc false
  def changeset(unread_notification, attrs) do
    unread_notification
    |> cast(attrs, [])
    |> validate_required([])
  end
end
