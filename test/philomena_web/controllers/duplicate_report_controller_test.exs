defmodule PhilomenaWeb.DuplicateReportControllerTest do
  use PhilomenaWeb.ConnCase

  alias Philomena.DuplicateReports

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}

  def fixture(:duplicate_report) do
    {:ok, duplicate_report} = DuplicateReports.create_duplicate_report(@create_attrs)
    duplicate_report
  end

  describe "index" do
    test "lists all duplicate_reports", %{conn: conn} do
      conn = get(conn, Routes.duplicate_report_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Duplicate reports"
    end
  end

  describe "new duplicate_report" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.duplicate_report_path(conn, :new))
      assert html_response(conn, 200) =~ "New Duplicate report"
    end
  end

  describe "create duplicate_report" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, Routes.duplicate_report_path(conn, :create), duplicate_report: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.duplicate_report_path(conn, :show, id)

      conn = get(conn, Routes.duplicate_report_path(conn, :show, id))
      assert html_response(conn, 200) =~ "Show Duplicate report"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.duplicate_report_path(conn, :create), duplicate_report: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Duplicate report"
    end
  end

  describe "edit duplicate_report" do
    setup [:create_duplicate_report]

    test "renders form for editing chosen duplicate_report", %{conn: conn, duplicate_report: duplicate_report} do
      conn = get(conn, Routes.duplicate_report_path(conn, :edit, duplicate_report))
      assert html_response(conn, 200) =~ "Edit Duplicate report"
    end
  end

  describe "update duplicate_report" do
    setup [:create_duplicate_report]

    test "redirects when data is valid", %{conn: conn, duplicate_report: duplicate_report} do
      conn = put(conn, Routes.duplicate_report_path(conn, :update, duplicate_report), duplicate_report: @update_attrs)
      assert redirected_to(conn) == Routes.duplicate_report_path(conn, :show, duplicate_report)

      conn = get(conn, Routes.duplicate_report_path(conn, :show, duplicate_report))
      assert html_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, duplicate_report: duplicate_report} do
      conn = put(conn, Routes.duplicate_report_path(conn, :update, duplicate_report), duplicate_report: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Duplicate report"
    end
  end

  describe "delete duplicate_report" do
    setup [:create_duplicate_report]

    test "deletes chosen duplicate_report", %{conn: conn, duplicate_report: duplicate_report} do
      conn = delete(conn, Routes.duplicate_report_path(conn, :delete, duplicate_report))
      assert redirected_to(conn) == Routes.duplicate_report_path(conn, :index)
      assert_error_sent 404, fn ->
        get(conn, Routes.duplicate_report_path(conn, :show, duplicate_report))
      end
    end
  end

  defp create_duplicate_report(_) do
    duplicate_report = fixture(:duplicate_report)
    {:ok, duplicate_report: duplicate_report}
  end
end
