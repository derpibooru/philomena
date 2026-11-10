defmodule Philomena.ArtistLinks.QueryForm do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Philomena.ArtistLinks.ArtistLink

  @type t :: %__MODULE__{}

  embedded_schema do
    field :states, {:array, :string}, default: ArtistLink.pending_states()
    field :text, :string
  end

  @doc false
  def changeset(%__MODULE__{} = query_form, attrs \\ %{}) do
    query_form
    |> cast(attrs, [:states, :text])
    |> validate_subset(:states, ArtistLink.states())
  end
end
