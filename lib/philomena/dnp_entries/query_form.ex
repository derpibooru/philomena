defmodule Philomena.DnpEntries.QueryForm do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.DnpEntries.DnpEntry

  @type t :: %__MODULE__{}

  embedded_schema do
    field :states, {:array, :string}, default: DnpEntry.active_states()
    field :text, :string
  end

  @doc false
  def changeset(%__MODULE__{} = query_form, attrs \\ %{}) do
    query_form
    |> cast(attrs, [:states, :text])
    |> validate_subset(:states, DnpEntry.states())
  end
end
