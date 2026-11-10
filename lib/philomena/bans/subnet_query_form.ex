defmodule Philomena.Bans.SubnetQueryForm do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  embedded_schema do
    field :bq, :string
    field :ip, EctoNetwork.INET
  end

  @doc false
  def changeset(%__MODULE__{} = query_form, attrs \\ %{}) do
    cast(query_form, attrs, [:bq, :ip])
  end
end
