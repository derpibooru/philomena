defmodule PhilomenaWeb.Admin.ReportControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  # The index action reads the Report OpenSearch index, so this module is
  # search-backed.

  @moduletag :search

  import Philomena.ReportsFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures
  import Philomena.BadgesFixtures

  alias Philomena.Reports.Report
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers

  setup do
    Search.clear_index!(Report)
    :ok
  end

  defp open_report_fixture do
    image = image_fixture()
    report_fixture(image_id: image.id)
  end

  # An orphaned report retains its rule and reporter but has all columns
  # NULL, as if its target had been deleted (the FK nilify path). Built from a
  # real report, then the column is nulled to simulate target deletion.
  defp orphan_report_fixture do
    image = image_fixture()
    report = report_fixture(image_id: image.id)

    {:ok, orphan} =
      report
      |> Ecto.Changeset.change(%{image_id: nil})
      |> Philomena.Repo.update()

    orphan
  end

  describe "GET /admin/reports authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      conn = get(conn, ~p"/admin/reports")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/reports")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "allows a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/reports")
      assert html_response(conn, 200) =~ "Reports"
    end

    test "allows an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/reports")
      assert html_response(conn, 200) =~ "Reports"
    end
  end

  describe "GET /admin/reports (index) content" do
    setup [:register_and_log_in_admin]

    test "an empty rq parameter uses the default report query", %{conn: conn} do
      report = open_report_fixture()
      SearchHelpers.reindex_all!(Report)

      conn = get(conn, ~p"/admin/reports?rq=")

      assert html_response(conn, 200) =~ report.reason
    end

    test "renders the empty index", %{conn: conn} do
      conn = get(conn, ~p"/admin/reports")
      response = html_response(conn, 200)
      assert response =~ "Admin - Reports - Derpibooru"
      assert response =~ "We couldn't find any reports for you, sorry!"
    end

    test "lists an open report in the default view", %{conn: conn} do
      report = open_report_fixture()
      SearchHelpers.reindex_all!(Report)

      conn = get(conn, ~p"/admin/reports")
      response = html_response(conn, 200)
      assert response =~ report.reason
    end

    test "supports the rq search branch", %{conn: conn} do
      report = open_report_fixture()
      SearchHelpers.reindex_all!(Report)

      conn = get(conn, ~p"/admin/reports?#{[rq: [query: "open:true"]]}")
      response = html_response(conn, 200)
      assert response =~ report.reason
    end
  end

  describe "GET /admin/reports/:id (show) authorization" do
    setup do
      %{report: open_report_fixture()}
    end

    test "redirects anonymous users to login", %{conn: conn, report: report} do
      conn = get(conn, ~p"/admin/reports/#{report}")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn, report: report} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/reports/#{report}")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "allows a moderator", %{conn: conn, report: report} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/reports/#{report}")
      response = html_response(conn, 200)
      assert response =~ "Showing Report"
      assert response =~ report.reason
    end
  end

  describe "GET /admin/reports/:id (show) with a signed-in reporter" do
    setup [:register_and_log_in_admin]

    test "renders the reporter's name and badges", %{conn: conn, user: admin} do
      reporter = user_fixture()
      badge = badge_fixture()
      badge_award_fixture(admin, reporter, badge)

      image = image_fixture()
      report = report_fixture(reporter, %{}, image_id: image.id)

      conn = get(conn, ~p"/admin/reports/#{report}")
      response = html_response(conn, 200)
      assert response =~ "Showing Report"
      assert response =~ reporter.name
      assert response =~ badge.title
    end
  end

  describe "orphaned report rendering" do
    setup [:register_and_log_in_admin]

    test "the show page renders the permanently-destroyed fallback", %{conn: conn} do
      report = orphan_report_fixture()

      conn = get(conn, ~p"/admin/reports/#{report}")
      response = html_response(conn, 200)
      assert response =~ "Showing Report"
      assert response =~ "Reported item permanently destroyed."
    end

    test "the index renders an orphaned report without crashing", %{conn: conn} do
      report = orphan_report_fixture()
      SearchHelpers.reindex_all!(Report)

      conn = get(conn, ~p"/admin/reports")
      response = html_response(conn, 200)
      assert response =~ report.reason
      assert response =~ "Reported item permanently destroyed."
    end
  end

  describe "GET /admin/reports/:id (show) failure paths" do
    setup [:register_and_log_in_admin]

    # NOTE: an unknown id loads nil; an admin is authorized on the nil load, so
    # :show returns not_found.
    test "redirects for an unknown report id", %{conn: conn} do
      conn = get(conn, ~p"/admin/reports/#{0}")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    # NOTE: a non-integer report id short-circuits to NotFoundPlug via the
    # central IntegerId guard.
    test "redirects with the not-found flash for a non-integer report id", %{conn: conn} do
      conn = get(conn, ~p"/admin/reports/not-an-integer")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end
end
