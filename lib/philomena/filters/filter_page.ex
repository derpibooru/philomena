defmodule Philomena.Filters.FilterPage do
  @moduledoc """
  The assembled filter page: the filter with its `:user` preloaded, and its
  spoilered and hidden tags, each ordered by name.
  """

  alias Philomena.Filters.Filter
  alias Philomena.Tags.Tag

  @enforce_keys [:filter, :spoilered_tags, :hidden_tags]
  defstruct filter: nil,
            spoilered_tags: nil,
            hidden_tags: nil

  @type t :: %__MODULE__{
          filter: Filter.t(),
          spoilered_tags: [Tag.t()],
          hidden_tags: [Tag.t()]
        }
end
