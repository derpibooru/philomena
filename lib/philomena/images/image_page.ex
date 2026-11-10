defmodule Philomena.Images.ImagePage do
  @moduledoc """
  The per-viewer data gathered for one image: the image, the visible
  page of its comments, the viewer's subscription state and interactions,
  the viewer's galleries paired with whether they already contain the image,
  and changesets for each action available on the page.

  Comment and description bodies are carried in their raw form.
  """

  alias Philomena.Images.Image

  @enforce_keys [
    :image,
    :comments,
    :watching,
    :can_interact,
    :user_galleries,
    :interactions,
    :comment_changeset,
    :description_changeset,
    :tag_changeset,
    :source_changeset,
    :file_changeset,
    :hide_changeset,
    :feature_changeset,
    :repair_changeset,
    :hash_changeset,
    :uploader_changeset
  ]
  defstruct [
    :image,
    :comments,
    :watching,
    :can_interact,
    :user_galleries,
    :interactions,
    :comment_changeset,
    :description_changeset,
    :tag_changeset,
    :source_changeset,
    :file_changeset,
    :hide_changeset,
    :feature_changeset,
    :repair_changeset,
    :hash_changeset,
    :uploader_changeset
  ]

  @type t :: %__MODULE__{
          image: Image.t(),
          comments: Scrivener.Page.t(),
          watching: boolean(),
          can_interact: boolean(),
          user_galleries: [{Philomena.Galleries.Gallery.t(), boolean()}],
          interactions: list(),
          comment_changeset: Ecto.Changeset.t() | nil,
          description_changeset: Ecto.Changeset.t() | nil,
          tag_changeset: Ecto.Changeset.t() | nil,
          source_changeset: Ecto.Changeset.t() | nil,
          file_changeset: Ecto.Changeset.t() | nil,
          hide_changeset: Ecto.Changeset.t() | nil,
          feature_changeset: Ecto.Changeset.t() | nil,
          repair_changeset: Ecto.Changeset.t() | nil,
          hash_changeset: Ecto.Changeset.t() | nil,
          uploader_changeset: Ecto.Changeset.t() | nil
        }
end
