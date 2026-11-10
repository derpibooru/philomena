defmodule PhilomenaWeb.Gallery.ReportControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Ecto.Query
  import Philomena.GalleriesFixtures
  import Philomena.RulesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Reports.Report
  alias Philomena.Repo

  describe "GET /galleries/:gallery_id/reports/new" do
    test "renders the report form for anonymous users", %{conn: conn} do
      gallery = gallery_fixture(confirmed_user_fixture())

      response = html_response(get(conn, ~p"/galleries/#{gallery}/reports/new"), 200)

      assert response =~ "Reporting Gallery - Derpibooru"
      assert response =~ "Submit a report"
    end

    test "renders the report form for logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      gallery = gallery_fixture(confirmed_user_fixture())

      response = html_response(get(conn, ~p"/galleries/#{gallery}/reports/new"), 200)

      assert response =~ "Reporting Gallery - Derpibooru"
    end

    test "redirects to / with the not-found flash for an unknown gallery", %{conn: conn} do
      conn = get(conn, ~p"/galleries/999999999/reports/new")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "renders the report form without a fingerprint", %{conn: conn} do
      gallery = gallery_fixture(confirmed_user_fixture())

      conn = get(without_fingerprint(conn), ~p"/galleries/#{gallery}/reports/new")

      assert html_response(conn, 200) =~ "Reporting Gallery - Derpibooru"
    end
  end

  describe "POST /galleries/:gallery_id/reports" do
    test "as a logged-in user creates the report and redirects to /reports", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      gallery = gallery_fixture(confirmed_user_fixture())
      rule = rule_fixture()

      conn =
        post(conn, ~p"/galleries/#{gallery}/reports", %{
          "report" => %{
            "reason" => "Test gallery report",
            "rule_id" => rule.id,
            "user_agent" => "Test Browser/1.0"
          }
        })

      assert redirected_to(conn) == ~p"/reports"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Your report has been received and will be checked by staff shortly."

      report =
        Repo.one!(
          from r in Report,
            where: r.gallery_id == ^gallery.id
        )

      assert report.user_id == user.id
      assert report.state == "open"
    end

    test "anonymously creates the report and redirects to /", %{conn: conn} do
      gallery = gallery_fixture(confirmed_user_fixture())
      rule = rule_fixture()

      conn =
        post(conn, ~p"/galleries/#{gallery}/reports", %{
          "report" => %{
            "reason" => "Anonymous gallery report",
            "rule_id" => rule.id,
            "user_agent" => "Test Browser/1.0"
          }
        })

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Your report has been received and will be checked by staff shortly."

      report =
        Repo.one!(
          from r in Report,
            where: r.gallery_id == ^gallery.id
        )

      assert report.user_id == nil
    end

    test "with a blank reason re-renders the report form", %{conn: conn} do
      # NOTE: the create failure now renders new.html through the shared
      # PhilomenaWeb.ReportView (200) rather than raising on a missing view.
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      gallery = gallery_fixture(confirmed_user_fixture())
      rule = rule_fixture()

      conn =
        post(conn, ~p"/galleries/#{gallery}/reports", %{
          "report" => %{
            "reason" => "",
            "rule_id" => rule.id,
            "user_agent" => "Test Browser/1.0"
          }
        })

      assert html_response(conn, 200) =~ "Submit a report"
      assert Repo.aggregate(Report, :count) == 0
    end

    test "as a banned user redirects with the ban flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

      conn = post(conn, ~p"/galleries/999999999/reports", %{})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      gallery = gallery_fixture(confirmed_user_fixture())

      conn =
        post(without_fingerprint(conn), ~p"/galleries/#{gallery}/reports", %{
          "report" => %{
            "reason" => "Reported without a fingerprint",
            "rule_id" => rule_fixture().id,
            "user_agent" => "Test Browser/1.0"
          }
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.aggregate(Report, :count) == 0
    end
  end
end
