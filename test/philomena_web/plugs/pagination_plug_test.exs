defmodule PhilomenaWeb.PaginationPlugTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias PhilomenaWeb.PaginationPlug

  test "falls back to defaults for list or map pagination params" do
    conn =
      conn(:get, "/?page[]=2&per_page[a]=10")
      |> assign(:current_user, nil)
      |> PaginationPlug.call([])

    assert conn.assigns.pagination == %{page_number: 1, page_size: 25}
  end
end
