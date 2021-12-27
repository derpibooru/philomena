defmodule Philomena.Autocomplete.Autocomplete do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "autocomplete" do
    field :content, :binary
    timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
  end

  @doc false
  def changeset(autocomplete, attrs) do
    autocomplete
    |> cast(attrs, [:content])
    |> validate_required([:content])
  end
end
