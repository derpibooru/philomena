defmodule Philomena.Notifications.UnreadNotification do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "unread_notifications" do
    belongs_to :user, Philomena.Users.User, primary_key: true
    belongs_to :notification, Philomena.Notifications.Notification, primary_key: true
  end

  @doc false
  def changeset(unread_notification, attrs) do
    unread_notification
    |> cast(attrs, [])
    |> validate_required([])
  end
end
