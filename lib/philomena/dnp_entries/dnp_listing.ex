defmodule Philomena.DnpEntries.DnpListing do
  @moduledoc """
  The assembled Do-Not-Post listing: a paginated set of DNP entries, the
  viewer's linked tags, and whether the state column is included.
  """

  alias Philomena.Tags.Tag

  @enforce_keys [:dnp_entries, :linked_tags, :status_column]
  defstruct [:dnp_entries, :linked_tags, :status_column]

  @type t :: %__MODULE__{
          dnp_entries: Scrivener.Page.t(),
          linked_tags: [Tag.t()],
          status_column: boolean()
        }
end
