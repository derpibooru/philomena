defmodule PhilomenaWeb.TagChangeView do
  use PhilomenaWeb, :view

  def staff?(tag_change),
    do:
      not is_nil(tag_change.user) and not Philomena.Attribution.anonymous?(tag_change) and
        tag_change.user.role != "user" and not tag_change.user.hide_default_role

  def user_block_class(tag_change) do
    if staff?(tag_change) do
      "tag__change--staff"
    else
      nil
    end
  end

  def reverts_tag_changes?(conn),
    do: can?(conn, :revert, Philomena.TagChanges.TagChange)

  def non_retained_tags(%{image: image, tags: tags}) do
    tags
    |> Enum.filter(fn tct ->
      tct.added != Enum.any?(image.tags, &(&1.id == tct.tag.id))
    end)
  end

  def tag_not_retained(non_retained, tag) do
    Enum.any?(non_retained, &(&1.tag_id == tag.tag_id))
  end

  def non_retained_class(non_retained, tag) do
    if tag_not_retained(non_retained, tag) do
      "tag__change--not-retained"
    else
      ""
    end
  end
end
