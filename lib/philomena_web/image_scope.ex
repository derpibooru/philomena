defmodule PhilomenaWeb.ImageScope do
  alias Philomena.Images.Search.Scope

  @doc """
  Extracts the image listing parameters worth carrying across page
  transitions into a keyword list for URL building.
  """
  def scope(conn) do
    []
    |> scope(conn, "q", :q)
    |> scope(conn, "sf", :sf)
    |> scope(conn, "sd", :sd)
    |> scope(conn, "del", :del)
    |> scope(conn, "sort", :sort)
    |> scope(conn, "hidden", :hidden)
  end

  @doc """
  Builds the viewer's `Philomena.Images.Search.Scope` from the request:
  compiled filter, raw params, and the image pagination window.
  """
  def search_scope(conn) do
    Scope.new(
      conn.assigns.image_filter.query,
      conn.assigns.image_pagination,
      conn.params
    )
  end

  defp scope(list, conn, key, key_atom) do
    case conn.params[key] do
      nil -> list
      "" -> list
      val -> [{key_atom, val} | list]
    end
  end
end
