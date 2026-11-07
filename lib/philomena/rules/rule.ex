defmodule Philomena.Rules.Rule do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @derive {Phoenix.Param, key: :position}
  schema "rules" do
    field :name, :string, default: ""
    field :title, :string, default: ""
    field :description, :string, default: ""
    field :short_description, :string, default: ""
    field :example, :string, default: ""
    field :position, :integer, default: 1
    field :highlight, :boolean, default: false
    field :hidden, :boolean, default: false
    field :internal, :boolean, default: false

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [
      :name,
      :title,
      :description,
      :short_description,
      :example,
      :position,
      :highlight,
      :hidden,
      :internal
    ])
    |> validate_required([
      :name,
      :position
    ])
    |> unique_constraint(:name)
    |> unique_constraint(:position)
  end
end
