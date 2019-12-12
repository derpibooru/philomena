defmodule PhilomenaWeb.Admin.DnpEntryView do
  use PhilomenaWeb, :view

  import PhilomenaWeb.DnpEntryView, only: [pretty_state: 1]

  def dnp_entry_row_class(%{aasm_state: state}) when state in ["closed", "listed"], do: "success"
  def dnp_entry_row_class(%{aasm_state: state}) when state in ["claimed", "acknowledged"], do: "warning"
  def dnp_entry_row_class(_dnp_entry), do: "danger"

  def state_param(states) when is_list(states), do: states
  def state_param(_states), do: []
end
