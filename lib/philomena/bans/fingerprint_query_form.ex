defmodule Philomena.Bans.FingerprintQueryForm do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  embedded_schema do
    field :bq, :string
    field :fingerprint, :string
  end

  @doc false
  def changeset(%__MODULE__{} = query_form, attrs \\ %{}) do
    cast(query_form, attrs, [:bq, :fingerprint])
  end
end
