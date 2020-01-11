defmodule PhilomenaWeb.Admin.DnpEntryView do
  use PhilomenaWeb, :view

  alias PhilomenaWeb.DnpEntryView

  defp pretty_state(dnp_entry),
    do: DnpEntryView.pretty_state(dnp_entry)

  def dnp_entry_row_class(%{aasm_state: state}) when state in ["closed", "listed"], do: "success"

  def dnp_entry_row_class(%{aasm_state: state}) when state in ["claimed", "acknowledged"],
    do: "warning"

  def dnp_entry_row_class(_dnp_entry), do: "danger"

  def state_param(states) when is_list(states), do: states
  def state_param(_states), do: []
end
