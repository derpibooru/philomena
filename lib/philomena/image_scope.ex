defmodule Philomena.ImageScope do
  def scope(conn) do
    []
    |> scope(conn, "q")
    |> scope(conn, "sf")
    |> scope(conn, "sd")
  end

  defp scope(list, conn, key) do
    case conn.params[key] do
      nil -> list
      ""  -> list
      val -> [{key, val} | list]
    end
  end
end