defmodule PhilomenaWeb.DnpEntryControllerTest do
  use PhilomenaWeb.ConnCase

  alias Philomena.DnpEntries

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}

  def fixture(:dnp_entry) do
    {:ok, dnp_entry} = DnpEntries.create_dnp_entry(@create_attrs)
    dnp_entry
  end

  describe "index" do
    test "lists all dnp_entries", %{conn: conn} do
      conn = get(conn, Routes.dnp_entry_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Dnp entries"
    end
  end

  describe "new dnp_entry" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.dnp_entry_path(conn, :new))
      assert html_response(conn, 200) =~ "New Dnp entry"
    end
  end

  describe "create dnp_entry" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, Routes.dnp_entry_path(conn, :create), dnp_entry: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.dnp_entry_path(conn, :show, id)

      conn = get(conn, Routes.dnp_entry_path(conn, :show, id))
      assert html_response(conn, 200) =~ "Show Dnp entry"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.dnp_entry_path(conn, :create), dnp_entry: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Dnp entry"
    end
  end

  describe "edit dnp_entry" do
    setup [:create_dnp_entry]

    test "renders form for editing chosen dnp_entry", %{conn: conn, dnp_entry: dnp_entry} do
      conn = get(conn, Routes.dnp_entry_path(conn, :edit, dnp_entry))
      assert html_response(conn, 200) =~ "Edit Dnp entry"
    end
  end

  describe "update dnp_entry" do
    setup [:create_dnp_entry]

    test "redirects when data is valid", %{conn: conn, dnp_entry: dnp_entry} do
      conn = put(conn, Routes.dnp_entry_path(conn, :update, dnp_entry), dnp_entry: @update_attrs)
      assert redirected_to(conn) == Routes.dnp_entry_path(conn, :show, dnp_entry)

      conn = get(conn, Routes.dnp_entry_path(conn, :show, dnp_entry))
      assert html_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, dnp_entry: dnp_entry} do
      conn = put(conn, Routes.dnp_entry_path(conn, :update, dnp_entry), dnp_entry: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Dnp entry"
    end
  end

  describe "delete dnp_entry" do
    setup [:create_dnp_entry]

    test "deletes chosen dnp_entry", %{conn: conn, dnp_entry: dnp_entry} do
      conn = delete(conn, Routes.dnp_entry_path(conn, :delete, dnp_entry))
      assert redirected_to(conn) == Routes.dnp_entry_path(conn, :index)
      assert_error_sent 404, fn ->
        get(conn, Routes.dnp_entry_path(conn, :show, dnp_entry))
      end
    end
  end

  defp create_dnp_entry(_) do
    dnp_entry = fixture(:dnp_entry)
    {:ok, dnp_entry: dnp_entry}
  end
end
