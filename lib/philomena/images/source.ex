defmodule Philomena.Images.Source do
  use Ecto.Schema
  import Ecto.Changeset

  schema "image_sources" do
    timestamps()
  end

  @doc false
  def changeset(source, attrs) do
    source
    |> cast(attrs, [])
    |> validate_required([])
  end
end
