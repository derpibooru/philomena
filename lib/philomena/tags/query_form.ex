defmodule Philomena.Tags.QueryForm do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import PhilomenaQuery.Ecto.QueryValidator

  alias Philomena.Tags.Query

  @type t :: %__MODULE__{}

  embedded_schema do
    field :query, :string
    field :compiled_query, :map, virtual: true
  end

  @doc false
  def changeset(%__MODULE__{} = query_form, attrs \\ %{}) do
    query_form
    |> cast(attrs, [:query])
    |> validate_query(:query, with: &Query.compile/1, into: :compiled_query)
  end
end
