defmodule PhilomenaWeb.ApiTokenPlugTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures

  alias PhilomenaWeb.ApiTokenPlug

  defp call_with_params(conn, params) do
    conn
    |> Map.put(:params, params)
    |> ApiTokenPlug.call([])
  end

  test "a valid key signs the request in as its user", %{conn: conn} do
    user = confirmed_user_fixture()

    conn = call_with_params(conn, %{"key" => user.authentication_token})

    assert conn.assigns.current_user.id == user.id
  end

  test "a missing or non-string key is anonymous", %{conn: conn} do
    assert call_with_params(conn, %{}).assigns.current_user == nil
    assert call_with_params(conn, %{"key" => ["x"]}).assigns.current_user == nil
  end
end
