defmodule Philomena.TagChanges.QueryForm do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import PhilomenaQuery.Ecto.QueryValidator

  alias Philomena.TagChanges.Query

  @type t :: %__MODULE__{}

  embedded_schema do
    field :tcq, :string
    field :sf, :string, default: "created_at"
    field :sd, :string, default: "desc"

    field :compiled_query, :map, virtual: true
  end

  @doc false
  def changeset(%__MODULE__{} = query_form, user, attrs \\ %{}) do
    query_form
    |> cast(attrs, [:tcq, :sf, :sd])
    |> validate_inclusion(:sf, ~w(created_at tag_count added_tag_count removed_tag_count))
    |> validate_inclusion(:sd, ~w(asc desc))
    |> validate_query(:tcq,
      with: &Query.compile(&1, user: user),
      default: "*",
      into: :compiled_query
    )
  end
end
