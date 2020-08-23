defmodule PhilomenaWeb.GalleryView do
  use PhilomenaWeb, :view

  alias PhilomenaWeb.ImageScope

  def scope(conn), do: ImageScope.scope(conn)

  def sortable_classes(%{assigns: %{gallery_prev: prev, gallery_next: next}}) do
    []
    |> sortable_prev(prev)
    |> sortable_next(next)
    |> Enum.join(" ")
  end

  def sortable_prev(list, false), do: list
  def sortable_prev(list, _), do: ["js-sortable-has-prev" | list]

  def sortable_next(list, false), do: list
  def sortable_next(list, _), do: ["js-sortable-has-next" | list]

  def show_subscription_link?(%{id: id}, %{id: id}), do: false
  def show_subscription_link?(_user1, _user2), do: true
end
