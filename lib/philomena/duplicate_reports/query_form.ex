defmodule Philomena.DuplicateReports.QueryForm do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  alias Philomena.DuplicateReports.DuplicateReport

  embedded_schema do
    field :states, {:array, :string}, default: DuplicateReport.open_states()
    field :sd, :string, default: "desc"
  end

  @doc false
  def changeset(%__MODULE__{} = query_form, attrs \\ %{}) do
    query_form
    |> cast(attrs, [:states, :sd])
    |> validate_subset(:states, DuplicateReport.valid_states())
    |> validate_inclusion(:sd, ~w(asc desc))
  end
end
