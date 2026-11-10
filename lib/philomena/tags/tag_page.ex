defmodule Philomena.Tags.TagPage do
  @moduledoc """
  The assembled tag page: the tag with its preloads, the executed
  page of images tagged with it, the viewer's interactions with those images,
  and the escaped search query that lists the tag.

  The tag carries raw records, not rendered output.
  """

  alias Philomena.Tags.Tag

  @enforce_keys [:tag, :images, :interactions, :search_query]
  defstruct tag: nil,
            images: nil,
            interactions: nil,
            search_query: nil

  @type t :: %__MODULE__{
          tag: Tag.t(),
          images: Scrivener.Page.t(),
          interactions: list(),
          search_query: String.t()
        }
end
