defmodule Philomena.Commissions.SearchQuery do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :item_type, :string
    field :category, {:array, :string}
    field :keywords, :string
    field :price_min, :decimal
    field :price_max, :decimal
  end

  @doc false
  def changeset(query, params) do
    cast(query, params, [:item_type, :category, :keywords, :price_min, :price_max])
  end
end
