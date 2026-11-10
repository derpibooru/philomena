defmodule Philomena.Conversations.QueryForm do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @int_max 2_147_483_647

  embedded_schema do
    field :with, :integer
  end

  @doc false
  def changeset(query, attrs \\ %{}) do
    query
    |> cast(attrs, [:with])
    |> validate_number(:with, greater_than: 0, less_than_or_equal_to: @int_max)
  end
end
