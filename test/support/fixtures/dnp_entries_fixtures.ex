defmodule Philomena.DnpEntriesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.DnpEntries` context.
  """

  alias Philomena.DnpEntries.DnpEntry
  alias Philomena.Repo

  @doc """
  Creates a DNP entry for `tag`, requested by `user`. Starts out in the
  default `"requested"` state; pass `state:` to transition it afterwards
  (the transition is attributed to the requesting user, the way a mod
  processing the request would be recorded).

  String-keyed attrs mirror the DNP controller form (`"dnp_type"`,
  `"reason"`, `"conditions"`, `"hide_reason"`, `"instructions"`).
  """
  def dnp_entry_fixture(user, tag, attrs \\ %{}) do
    {state, attrs} = Map.pop(attrs, :state)

    attrs =
      Enum.into(attrs, %{
        "tag_id" => to_string(tag.id),
        "dnp_type" => "No Edits",
        "reason" => "Test DNP reason",
        "conditions" => "Test DNP conditions"
      })

    dnp_entry =
      %DnpEntry{}
      |> DnpEntry.creation_changeset(attrs, user, [tag.id])
      |> Repo.insert!()

    case state do
      nil ->
        dnp_entry

      state ->
        dnp_entry
        |> DnpEntry.transition_changeset(user, state)
        |> Repo.update!()
    end
  end
end
