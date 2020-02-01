defmodule PhilomenaWeb.DnpEntryView do
  use PhilomenaWeb, :view

  def reasons do
    Philomena.DnpEntries.DnpEntry.reasons()
  end

  def form_class(changeset) do
    case show_steps?(changeset) do
      true -> "hidden"
      false -> nil
    end
  end

  def selectable_options(tags) do
    Enum.map(tags, &{&1.name, &1.id})
  end

  def selectable_types do
    Enum.map(reasons(), fn {k, v} -> [key: v, value: k] end)
  end

  def pretty_state(%{aasm_state: "claimed"}), do: "Claimed"
  def pretty_state(%{aasm_state: "listed"}), do: "Listed"
  def pretty_state(%{aasm_state: "closed"}), do: "Closed"
  def pretty_state(%{aasm_state: "acknowledged"}), do: "Claimed (Rescinded)"
  def pretty_state(_dnp_entry), do: "Requested"

  def show_steps?(changeset) do
    changeset.action == nil and changeset.data.__meta__.state != :loaded
  end
end
