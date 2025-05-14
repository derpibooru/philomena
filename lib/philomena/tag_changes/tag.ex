defmodule Philomena.TagChanges.Tag do
  use Ecto.Schema

  @primary_key false
  schema "tag_change_tags" do
    belongs_to :tag_change, Philomena.TagChanges.TagChange
    belongs_to :tag, Philomena.Tags.Tag

    field :added, :boolean
  end
end
