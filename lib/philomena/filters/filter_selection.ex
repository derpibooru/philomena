defmodule Philomena.Filters.FilterSelection do
  @moduledoc """
  The filter selection menu. Contains grouped, ordered recent and personal
  filter choices for a given user.
  """

  alias Philomena.Filters.Filter

  @enforce_keys [:user_filters, :recent_filters]
  defstruct [:user_filters, :recent_filters]

  @type t :: %__MODULE__{
          user_filters: [Filter.t()],
          recent_filters: [Filter.t()]
        }
end
