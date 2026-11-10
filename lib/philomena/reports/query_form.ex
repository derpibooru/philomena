defmodule Philomena.Reports.QueryForm do
  use Ecto.Schema

  import Ecto.Changeset
  import PhilomenaQuery.Ecto.QueryValidator

  @type t :: %__MODULE__{}

  alias Philomena.Reports.Query

  embedded_schema do
    field :query, :string

    field :compiled_query, :map, virtual: true
  end

  @doc false
  def changeset(query_form, admin_id, attrs \\ %{}) do
    query_form
    |> cast(attrs, [:query])
    |> validate_query(
      :query,
      with: &Query.compile/1,
      default: "(open:true AND NOT (admin_id:#{admin_id} OR system:true)) OR open:false",
      into: :compiled_query
    )
  end
end
