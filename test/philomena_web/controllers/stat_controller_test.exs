defmodule PhilomenaWeb.StatControllerTest do
  use PhilomenaWeb.ConnCase

  alias Philomena.Stats

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}

  def fixture(:stat) do
    {:ok, stat} = Stats.create_stat(@create_attrs)
    stat
  end

  describe "index" do
    test "lists all stats", %{conn: conn} do
      conn = get(conn, Routes.stat_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Stats"
    end
  end

  describe "new stat" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.stat_path(conn, :new))
      assert html_response(conn, 200) =~ "New Stat"
    end
  end

  describe "create stat" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, Routes.stat_path(conn, :create), stat: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.stat_path(conn, :show, id)

      conn = get(conn, Routes.stat_path(conn, :show, id))
      assert html_response(conn, 200) =~ "Show Stat"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.stat_path(conn, :create), stat: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Stat"
    end
  end

  describe "edit stat" do
    setup [:create_stat]

    test "renders form for editing chosen stat", %{conn: conn, stat: stat} do
      conn = get(conn, Routes.stat_path(conn, :edit, stat))
      assert html_response(conn, 200) =~ "Edit Stat"
    end
  end

  describe "update stat" do
    setup [:create_stat]

    test "redirects when data is valid", %{conn: conn, stat: stat} do
      conn = put(conn, Routes.stat_path(conn, :update, stat), stat: @update_attrs)
      assert redirected_to(conn) == Routes.stat_path(conn, :show, stat)

      conn = get(conn, Routes.stat_path(conn, :show, stat))
      assert html_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, stat: stat} do
      conn = put(conn, Routes.stat_path(conn, :update, stat), stat: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Stat"
    end
  end

  describe "delete stat" do
    setup [:create_stat]

    test "deletes chosen stat", %{conn: conn, stat: stat} do
      conn = delete(conn, Routes.stat_path(conn, :delete, stat))
      assert redirected_to(conn) == Routes.stat_path(conn, :index)
      assert_error_sent 404, fn ->
        get(conn, Routes.stat_path(conn, :show, stat))
      end
    end
  end

  defp create_stat(_) do
    stat = fixture(:stat)
    {:ok, stat: stat}
  end
end
