defmodule PhilomenaWeb.SearchView do
  use PhilomenaWeb, :view

  def scope(conn), do: Philomena.ImageScope.scope(conn)
  def hides_images?(conn), do: can?(conn, :hide, %Philomena.Images.Image{})
end
