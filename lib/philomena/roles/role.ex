defmodule Philomena.Roles.Role do
  use Ecto.Schema
  import Ecto.Changeset

  schema "roles" do
    field :name, :string

    # fixme: rails polymorphic relation
    field :resource_id, :integer
    field :resource_type, :string

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(role, attrs) do
    role
    |> cast(attrs, [])
    |> validate_required([])
  end
end
