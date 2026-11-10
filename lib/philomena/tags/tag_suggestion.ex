defmodule Philomena.Tags.TagSuggestion do
  @moduledoc """
  A search-as-you-type match with its canonical tag and current image count.
  """

  @enforce_keys [:alias, :canonical, :images]
  defstruct [:alias, :canonical, :images]

  @type t :: %__MODULE__{
          alias: String.t() | nil,
          canonical: String.t(),
          images: non_neg_integer()
        }
end
