defmodule PhilomenaWeb.Admin.Report.CloseControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ReportsFixtures
  import Philomena.ImagesFixtures

  alias Philomena.Reports.Report
  alias Philomena.Repo

  defp report_fixture!(_context) do
    image = image_fixture()
    %{report: report_fixture(image_id: image.id)}
  end

  describe "POST /admin/reports/:report_id/close authorization" do
    setup :report_fixture!

    test "redirects anonymous users to login", %{conn: conn, report: report} do
      conn = post(conn, ~p"/admin/reports/#{report}/close")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn, report: report} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = post(conn, ~p"/admin/reports/#{report}/close")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "POST /admin/reports/:report_id/close (create)" do
    setup [:register_and_log_in_moderator, :report_fixture!]

    test "closes the report and redirects to the index", %{conn: conn, report: report, user: mod} do
      conn = post(conn, ~p"/admin/reports/#{report}/close")
      assert redirected_to(conn) == ~p"/admin/reports"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "closed"

      updated = Repo.get(Report, report.id)
      assert updated.open == false
      assert updated.state == "closed"
      assert updated.admin_id == mod.id
    end
  end

  describe "POST /admin/reports/:report_id/close (create) failure paths" do
    setup [:register_and_log_in_moderator]

    test "redirects for an unknown report id", %{conn: conn} do
      conn = post(conn, ~p"/admin/reports/#{0}/close")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "redirects with the not-found flash for a non-integer report id", %{conn: conn} do
      conn = post(conn, ~p"/admin/reports/not-an-integer/close")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end
end
