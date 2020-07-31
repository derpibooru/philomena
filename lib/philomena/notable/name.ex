defmodule Philomena.Notable.Name do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notable_names" do
    field :name, :string
    field :source, :string

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(name, attrs) do
    name
    |> cast(attrs, [])
    |> validate_required([])
  end
end
