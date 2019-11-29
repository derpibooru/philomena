defmodule PhilomenaWeb.StaffControllerTest do
  use PhilomenaWeb.ConnCase

  alias Philomena.Staffs

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}

  def fixture(:staff) do
    {:ok, staff} = Staffs.create_staff(@create_attrs)
    staff
  end

  describe "index" do
    test "lists all staffs", %{conn: conn} do
      conn = get(conn, Routes.staff_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Staffs"
    end
  end

  describe "new staff" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.staff_path(conn, :new))
      assert html_response(conn, 200) =~ "New Staff"
    end
  end

  describe "create staff" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, Routes.staff_path(conn, :create), staff: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.staff_path(conn, :show, id)

      conn = get(conn, Routes.staff_path(conn, :show, id))
      assert html_response(conn, 200) =~ "Show Staff"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.staff_path(conn, :create), staff: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Staff"
    end
  end

  describe "edit staff" do
    setup [:create_staff]

    test "renders form for editing chosen staff", %{conn: conn, staff: staff} do
      conn = get(conn, Routes.staff_path(conn, :edit, staff))
      assert html_response(conn, 200) =~ "Edit Staff"
    end
  end

  describe "update staff" do
    setup [:create_staff]

    test "redirects when data is valid", %{conn: conn, staff: staff} do
      conn = put(conn, Routes.staff_path(conn, :update, staff), staff: @update_attrs)
      assert redirected_to(conn) == Routes.staff_path(conn, :show, staff)

      conn = get(conn, Routes.staff_path(conn, :show, staff))
      assert html_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, staff: staff} do
      conn = put(conn, Routes.staff_path(conn, :update, staff), staff: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Staff"
    end
  end

  describe "delete staff" do
    setup [:create_staff]

    test "deletes chosen staff", %{conn: conn, staff: staff} do
      conn = delete(conn, Routes.staff_path(conn, :delete, staff))
      assert redirected_to(conn) == Routes.staff_path(conn, :index)
      assert_error_sent 404, fn ->
        get(conn, Routes.staff_path(conn, :show, staff))
      end
    end
  end

  defp create_staff(_) do
    staff = fixture(:staff)
    {:ok, staff: staff}
  end
end
