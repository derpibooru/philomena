defmodule Philomena.ImageScope do
  def scope(conn) do
    []
    |> scope(conn, "q", :q)
    |> scope(conn, "sf", :sf)
    |> scope(conn, "sd", :sd)
  end

  defp scope(list, conn, key, key_atom) do
    case conn.params[key] do
      nil -> list
      ""  -> list
      val -> [{key_atom, val} | list]
    end
  end
end