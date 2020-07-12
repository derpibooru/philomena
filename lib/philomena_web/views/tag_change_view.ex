defmodule PhilomenaWeb.TagChangeView do
  use PhilomenaWeb, :view

  def staff?(tag_change),
    do:
      not is_nil(tag_change.user) and not Philomena.Attribution.anonymous?(tag_change) and
        tag_change.user.role != "user" and not tag_change.user.hide_default_role

  def user_column_class(tag_change) do
    case staff?(tag_change) do
      true -> "success"
      false -> nil
    end
  end

  def reverts_tag_changes?(conn),
    do: can?(conn, :revert, Philomena.TagChanges.TagChange)
end
