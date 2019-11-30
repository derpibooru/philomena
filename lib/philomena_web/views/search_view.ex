defmodule PhilomenaWeb.SearchView do
  use PhilomenaWeb, :view

  def scope(conn), do: Philomena.ImageScope.scope(conn)
end
