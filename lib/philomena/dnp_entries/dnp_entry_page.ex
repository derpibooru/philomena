defmodule Philomena.DnpEntries.DnpEntryPage do
  @moduledoc """
  An authorized DNP entry and its optional rendered moderation notes.

  `mod_notes` is `nil` when the viewer may not read moderation notes.
  """

  alias Philomena.DnpEntries.DnpEntry

  @enforce_keys [:dnp_entry, :mod_notes]
  defstruct [:dnp_entry, :mod_notes]

  @type t :: %__MODULE__{dnp_entry: DnpEntry.t(), mod_notes: list() | nil}
end
