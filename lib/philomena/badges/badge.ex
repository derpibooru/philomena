defmodule Philomena.Badges.Badge do
  use Ecto.Schema
  import Ecto.Changeset

  schema "badges" do
    field :title, :string
    field :description, :string
    field :image, :string
    field :disable_award, :boolean, default: false
    field :priority, :boolean, default: false

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(badge, attrs) do
    badge
    |> cast(attrs, [])
    |> validate_required([])
  end
end
