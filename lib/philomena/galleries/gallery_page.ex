defmodule Philomena.Galleries.GalleryPage do
  @moduledoc """
  Everything the gallery page needs for one viewer: the gallery, the
  visible page of its images (paired with their search hits), the images on
  the adjacent pages folded into one ordered list, whether
  those adjacent pages exist, the viewer's interactions, and their
  subscription state.

  `gallery_images` is the concatenation of the previous page, this page, and
  the next page, each entry a `{image, hit}` tuple; `gallery_prev` and
  `gallery_next` report only whether those neighbouring pages hold anything.
  """

  alias Philomena.Galleries.Gallery
  alias Philomena.Images.Image

  @enforce_keys [
    :gallery,
    :images,
    :gallery_images,
    :gallery_prev,
    :gallery_next,
    :interactions,
    :watching
  ]
  defstruct [
    :gallery,
    :images,
    :gallery_images,
    :gallery_prev,
    :gallery_next,
    :interactions,
    :watching
  ]

  @type t :: %__MODULE__{
          gallery: Gallery.t(),
          images: Scrivener.Page.t(),
          gallery_images: [{Image.t(), map()}],
          gallery_prev: boolean(),
          gallery_next: boolean(),
          interactions: list(),
          watching: boolean()
        }
end
