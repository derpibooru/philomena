defmodule Philomena.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    field :action, :string

    # fixme: rails polymorphic relation
    field :actor_id, :integer
    field :actor_type, :string
    field :actor_child_id, :integer
    field :actor_child_type, :string

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [])
    |> validate_required([])
  end
end
