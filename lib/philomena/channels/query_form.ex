defmodule Philomena.Channels.QueryForm do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  embedded_schema do
    field :cq, :string
  end

  @doc false
  def changeset(%__MODULE__{} = query_form, attrs \\ %{}) do
    cast(query_form, attrs, [:cq])
  end
end
