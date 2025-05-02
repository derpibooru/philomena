defmodule PhilomenaWeb.TagChangeView do
  use PhilomenaWeb, :view

  def staff?(tag_change),
    do:
      not is_nil(tag_change.user) and not Philomena.Attribution.anonymous?(tag_change) and
        tag_change.user.role != "user" and not tag_change.user.hide_default_role

  def user_column_class(tag_change) do
    if staff?(tag_change) do
      "success"
    else
      nil
    end
  end

  def reverts_tag_changes?(conn),
    do: can?(conn, :revert, Philomena.TagChanges.TagChange)

  def tag_change_retained(%{image: image, added: added, tag: %{id: tag_id}}) do
    added == Enum.any?(image.tags, &(&1.id == tag_id))
  end

  def tag_change_retained(%{image: image, added: added, tag_name_cache: tag_name}) do
    added == Enum.any?(image.tags, &(&1.name == tag_name))
  end

  def tag_change_retained(_), do: false
end
