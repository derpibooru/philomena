defmodule Philomena.DnpEntries.DnpEntryForm do
  @moduledoc """
  A new or existing DNP entry, its changeset, and the tags available to the
  acting user.

  The same shape is returned for initial form renders and validation failures.
  """

  alias Philomena.DnpEntries.DnpEntry
  alias Philomena.Tags.Tag

  @enforce_keys [:dnp_entry, :changeset, :selectable_tags]
  defstruct [:dnp_entry, :changeset, :selectable_tags]

  @type t :: %__MODULE__{
          dnp_entry: DnpEntry.t(),
          changeset: Ecto.Changeset.t(),
          selectable_tags: [Tag.t()]
        }
end
