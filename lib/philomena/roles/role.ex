defmodule Philomena.Roles.Role do
  use Ecto.Schema
  import Ecto.Changeset

  schema "roles" do
    field :name, :string
    field :resource_type, :string
  end

  @doc false
  def changeset(role, attrs) do
    role
    |> cast(attrs, [])
    |> validate_required([])
  end
end
