defmodule PhilomenaWeb.DuplicateReport.RejectControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ImagesFixtures
  import Philomena.DuplicateReportsFixtures

  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.Repo

  describe "POST /duplicate_reports/:duplicate_report_id/reject" do
    test "is rejected for anonymous users", %{conn: conn} do
      dr = duplicate_report_fixture(image_fixture(), image_fixture())

      conn = post(conn, ~p"/duplicate_reports/#{dr}/reject")

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "is rejected for regular users", %{conn: conn} do
      conn = log_in_user(conn, Philomena.UsersFixtures.confirmed_user_fixture())
      dr = duplicate_report_fixture(image_fixture(), image_fixture())

      conn = post(conn, ~p"/duplicate_reports/#{dr}/reject")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
    end

    test "a moderator rejects the report", %{conn: conn} do
      %{conn: conn, user: mod} = register_and_log_in_moderator(%{conn: conn})
      dr = duplicate_report_fixture(image_fixture(), image_fixture())

      conn = post(conn, ~p"/duplicate_reports/#{dr}/reject")

      assert html_response(conn, 200)

      dr = Repo.get!(DuplicateReport, dr.id)
      assert dr.state == "rejected"
      assert dr.modifier_id == mod.id
    end

    test "an unknown report id takes the not-found redirect", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/duplicate_reports/#{123_456_789}/reject")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "a non-integer report id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/duplicate_reports/not-an-integer/reject")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end
end
