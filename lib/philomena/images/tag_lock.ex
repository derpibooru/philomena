defmodule Philomena.Images.TagLock do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Images.Image
  alias Philomena.Tags.Tag

  @primary_key false

  schema "image_tag_locks" do
    belongs_to :image, Image, primary_key: true
    belongs_to :tag, Tag, primary_key: true
  end

  @doc false
  def changeset(tag_lock, attrs) do
    tag_lock
    |> cast(attrs, [])
    |> validate_required([])
  end
end
