defmodule PhilomenaWeb.ApiRequireAuthorizationPlugTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.BansFixtures

  alias PhilomenaWeb.ApiRequireAuthorizationPlug

  test "an anonymous request from a banned subnet is unauthorized", %{conn: conn} do
    subnet_ban_fixture(%{"specification" => "203.0.113.0/24"})

    conn =
      conn
      |> Map.put(:remote_ip, {203, 0, 113, 7})
      |> assign(:current_user, nil)
      |> ApiRequireAuthorizationPlug.call([])

    assert conn.halted
    assert response(conn, 401) == ""
  end
end
