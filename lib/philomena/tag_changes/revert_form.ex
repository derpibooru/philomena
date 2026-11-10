defmodule Philomena.TagChanges.RevertForm do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  embedded_schema do
    field :ids, {:array, :integer}
  end

  @doc false
  def changeset(%__MODULE__{} = revert_form, attrs \\ %{}) do
    revert_form
    |> cast(attrs, [:ids])
    |> validate_required(:ids)
    |> update_change(:ids, &Enum.uniq/1)
  end
end
