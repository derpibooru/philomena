defmodule Philomena.Comments.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "comments" do

    timestamps()
  end

  @doc false
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [])
    |> validate_required([])
  end
end
