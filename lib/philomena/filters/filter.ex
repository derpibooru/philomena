defmodule Philomena.Filters.Filter do
  use Ecto.Schema
  import Ecto.Changeset

  schema "filters" do
    belongs_to :user, Philomena.Users.User

    field :name, :string
    field :description, :string
    field :system, :boolean
    field :public, :boolean
    field :hidden_complex_str, :string
    field :spoilered_complex_str, :string
    field :hidden_tag_ids, {:array, :integer}, default: []
    field :spoilered_tag_ids, {:array, :integer}, default: []
    field :user_count, :integer, default: 0

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(filter, attrs) do
    filter
    |> cast(attrs, [])
    |> validate_required([])
  end
end
