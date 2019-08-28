defmodule Philomena.Versions.Version do
  use Ecto.Schema
  import Ecto.Changeset

  schema "versions" do
    field :event, :string
    field :whodunnit, :string
    field :object, :string

    # fixme: rails polymorphic relation
    field :item_id, :integer
    field :item_type, :string

    timestamps(inserted_at: :created_at, updated_at: false)
  end

  @doc false
  def changeset(version, attrs) do
    version
    |> cast(attrs, [])
    |> validate_required([])
  end
end
