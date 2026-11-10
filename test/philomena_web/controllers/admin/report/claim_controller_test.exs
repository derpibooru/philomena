defmodule PhilomenaWeb.Admin.Report.ClaimControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ReportsFixtures
  import Philomena.ImagesFixtures

  alias Philomena.Reports.Report
  alias Philomena.Repo

  defp report_fixture!(_context) do
    image = image_fixture()
    %{report: report_fixture(image_id: image.id)}
  end

  describe "POST /admin/reports/:report_id/claim authorization" do
    setup :report_fixture!

    test "redirects anonymous users to login", %{conn: conn, report: report} do
      conn = post(conn, ~p"/admin/reports/#{report}/claim")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn, report: report} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = post(conn, ~p"/admin/reports/#{report}/claim")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "POST /admin/reports/:report_id/claim (create)" do
    setup [:register_and_log_in_moderator, :report_fixture!]

    test "claims the report for the moderator", %{conn: conn, report: report, user: mod} do
      conn = post(conn, ~p"/admin/reports/#{report}/claim")
      assert redirected_to(conn) == ~p"/admin/reports"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "in progress"

      updated = Repo.get(Report, report.id)
      assert updated.admin_id == mod.id
      assert updated.open == true
    end
  end

  describe "POST /admin/reports/:report_id/claim (create) failure paths" do
    setup [:register_and_log_in_moderator]

    test "redirects for an unknown report id", %{conn: conn} do
      conn = post(conn, ~p"/admin/reports/#{0}/claim")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "redirects with the not-found flash for a non-integer report id", %{conn: conn} do
      conn = post(conn, ~p"/admin/reports/not-an-integer/claim")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end

  describe "DELETE /admin/reports/:report_id/claim authorization" do
    setup :report_fixture!

    test "redirects anonymous users to login", %{conn: conn, report: report} do
      conn = delete(conn, ~p"/admin/reports/#{report}/claim")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn, report: report} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = delete(conn, ~p"/admin/reports/#{report}/claim")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "DELETE /admin/reports/:report_id/claim (delete)" do
    setup [:register_and_log_in_moderator, :report_fixture!]

    test "releases the report and redirects to the report", %{
      conn: conn,
      report: report,
      user: mod
    } do
      {:ok, _report} =
        Philomena.Reports.create_report_claim(Philomena.AttributionFixtures.actor(mod), report.id)

      conn = delete(conn, ~p"/admin/reports/#{report}/claim")
      assert redirected_to(conn) == ~p"/admin/reports/#{report}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "released"

      updated = Repo.get(Report, report.id)
      assert is_nil(updated.admin_id)
    end
  end
end
