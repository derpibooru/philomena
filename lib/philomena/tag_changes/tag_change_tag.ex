defmodule Philomena.TagChanges.TagChangeTag do
  @moduledoc """
  A tag assignment recorded by a tag change.

  This is the join row between `TagChanges.TagChange` and `Tags.Tag`, not a
  tag record itself.
  """

  use Ecto.Schema

  @primary_key false
  schema "tag_change_tags" do
    belongs_to :tag_change, Philomena.TagChanges.TagChange
    belongs_to :tag, Philomena.Tags.Tag

    field :added, :boolean
  end
end
