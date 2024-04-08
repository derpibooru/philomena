defmodule PhilomenaWeb.SearchView do
  use PhilomenaWeb, :view

  def scope(conn), do: PhilomenaWeb.ImageScope.scope(conn)
  def hides_images?(conn), do: can?(conn, :hide, %Philomena.Images.Image{})

  def override_display([{_tag, _description, dnp_entries}]) do
    Enum.any?(dnp_entries)
  end

  def override_display(_), do: false
end
