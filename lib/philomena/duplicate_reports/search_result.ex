defmodule Philomena.DuplicateReports.SearchResult do
  @moduledoc """
  The normalized reverse-image-search result rendered by HTML and JSON callers.
  """

  alias Philomena.Images.Image

  @enforce_keys [:images, :changeset]
  defstruct [:images, :changeset]

  @type t :: %__MODULE__{
          images: Scrivener.Page.t(Image.t()) | nil,
          changeset: Ecto.Changeset.t()
        }
end
