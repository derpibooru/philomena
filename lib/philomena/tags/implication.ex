defmodule Philomena.Tags.Implication do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Tags.Tag

  @primary_key false

  schema "tags_implied_tags" do
    belongs_to :tag, Tag, primary_key: true
    belongs_to :implied_tag, Tag, primary_key: true
  end

  @doc false
  def changeset(implication, attrs) do
    implication
    |> cast(attrs, [])
    |> validate_required([])
  end
end
