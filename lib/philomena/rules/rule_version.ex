defmodule Philomena.Rules.RuleVersion do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  alias Philomena.Rules.Rule
  alias Philomena.Users.User

  schema "rule_versions" do
    belongs_to :rule, Rule
    belongs_to :user, User

    field :name, :string, default: ""
    field :title, :string, default: ""
    field :description, :string, default: ""
    field :short_description, :string, default: ""
    field :example, :string, default: ""

    field :previous, :any, virtual: true
    field :differences, :any, virtual: true

    timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
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
      :rule_id,
      :user_id
    ])
    |> validate_required([
      :name,
      :rule_id
    ])
  end
end
