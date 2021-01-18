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

    field :actor, :any, virtual: true
    field :actor_child, :any, virtual: true

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:actor_id, :actor_type, :actor_child_id, :actor_child_type, :action])
    |> validate_required([:actor_id, :actor_type, :action])
  end
end
