defmodule PhilomenaWeb.Profile.Commission.ReportControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Ecto.Query
  import Philomena.CommissionsFixtures
  import Philomena.RulesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Reports.Report
  alias Philomena.Repo

  # Unlike the other report wrappers, these routes live in the
  # require_authenticated_user scope.

  describe "GET /profiles/:profile_id/commission/reports/new" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      artist = confirmed_user_fixture()
      commission_fixture(artist)

      conn = get(conn, ~p"/profiles/#{artist}/commission/reports/new")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "renders the report form for logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      artist = confirmed_user_fixture()
      commission_fixture(artist)

      response = html_response(get(conn, ~p"/profiles/#{artist}/commission/reports/new"), 200)

      assert response =~ "Reporting Commission - Derpibooru"
      assert response =~ "Submit a report"
    end

    test "redirects with the not-found flash when no commission exists", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      user = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{user}/commission/reports/new")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "renders the report form without a fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      artist = confirmed_user_fixture()
      commission_fixture(artist)

      conn = get(without_fingerprint(conn), ~p"/profiles/#{artist}/commission/reports/new")

      assert html_response(conn, 200) =~ "Reporting Commission - Derpibooru"
    end
  end

  describe "POST /profiles/:profile_id/commission/reports" do
    test "creates the report and redirects to /reports", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      artist = confirmed_user_fixture()
      commission = commission_fixture(artist)
      rule = rule_fixture()

      conn =
        post(conn, ~p"/profiles/#{artist}/commission/reports", %{
          "report" => %{
            "reason" => "Test commission report",
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
            where: r.commission_id == ^commission.id
        )

      assert report.user_id == user.id
      assert report.state == "open"
    end

    test "with a blank reason re-renders the report form", %{conn: conn} do
      # NOTE: the create failure now renders new.html through the shared
      # PhilomenaWeb.ReportView (200) rather than raising on a missing view.
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      artist = confirmed_user_fixture()
      commission_fixture(artist)
      rule = rule_fixture()

      conn =
        post(conn, ~p"/profiles/#{artist}/commission/reports", %{
          "report" => %{
            "reason" => "",
            "rule_id" => rule.id,
            "user_agent" => "Test Browser/1.0"
          }
        })

      assert html_response(conn, 200) =~ "Submit a report"
      assert Repo.aggregate(Report, :count) == 0
    end

    test "redirects banned users with the ban flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

      conn = post(conn, ~p"/profiles/some-user/commission/reports", %{})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      artist = confirmed_user_fixture()
      commission_fixture(artist)

      conn =
        post(without_fingerprint(conn), ~p"/profiles/#{artist}/commission/reports", %{
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
