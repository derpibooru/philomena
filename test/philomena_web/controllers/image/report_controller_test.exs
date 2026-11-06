defmodule PhilomenaWeb.Image.ReportControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Ecto.Query
  import Philomena.ImagesFixtures
  import Philomena.RulesFixtures

  alias Philomena.Reports.Report
  alias Philomena.Repo

  test "GET new renders the report form for anonymous users", %{conn: conn} do
    image = image_fixture()

    response = html_response(get(conn, ~p"/images/#{image}/reports/new"), 200)

    assert response =~ "Reporting Image - Derpibooru"
    assert response =~ ~r/<textarea[^>]*name="report\[reason\]"[^>]*required/
  end

  test "GET new renders the report form for logged-in users", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    image = image_fixture()

    response = html_response(get(conn, ~p"/images/#{image}/reports/new"), 200)

    assert response =~ "Reporting Image - Derpibooru"
  end

  test "GET new for an unknown image redirects to / with the not-found flash",
       %{conn: conn} do
    conn = get(conn, ~p"/images/999999999/reports/new")

    assert redirected_to(conn) == "/"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "Couldn't find what you were looking for!"
  end

  test "POST as a logged-in user creates the report and redirects to /reports", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    image = image_fixture()
    rule = rule_fixture()

    # the form embeds the browser's User-Agent as a hidden field, and the
    # changeset requires it to be non-empty
    conn =
      post(conn, ~p"/images/#{image}/reports", %{
        "report" => %{
          "reason" => "Test image report",
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
          where: r.image_id == ^image.id
      )

    assert report.user_id == user.id
    assert report.state == "open"
  end

  test "POST anonymously creates the report and redirects to /", %{conn: conn} do
    image = image_fixture()
    rule = rule_fixture()

    conn =
      post(conn, ~p"/images/#{image}/reports", %{
        "report" => %{
          "reason" => "Anonymous image report",
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
          where: r.image_id == ^image.id
      )

    assert report.user_id == nil
  end

  test "POST with a blank reason re-renders the report form", %{conn: conn} do
    # NOTE: the create failure now renders new.html through the shared
    # PhilomenaWeb.ReportView (200) rather than raising on a missing view.
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    image = image_fixture()
    rule = rule_fixture()

    conn =
      post(conn, ~p"/images/#{image}/reports", %{
        "report" => %{
          "reason" => "",
          "rule_id" => rule.id,
          "user_agent" => "Test Browser/1.0"
        }
      })

    assert html_response(conn, 200) =~ "Submit a report"
    assert Repo.aggregate(Report, :count) == 0
  end

  test "POST without a report map redirects with the not-found flash", %{conn: conn} do
    image = image_fixture()

    for params <- [%{}, %{"report" => "foo"}] do
      conn = post(conn, ~p"/images/#{image}/reports", params)

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end
  end

  test "POST with more than 5 open reports redirects to / with the limit flash",
       %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    image = image_fixture()
    rule = rule_fixture()

    for _ <- 1..5 do
      Philomena.ReportsFixtures.report_fixture(user, image_id: image.id)
    end

    conn =
      post(conn, ~p"/images/#{image}/reports", %{
        "report" => %{
          "reason" => "One report too many",
          "rule_id" => rule.id,
          "user_agent" => "Test Browser/1.0"
        }
      })

    assert redirected_to(conn) == "/"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
             "You may not have more than 5 open reports at a time"

    assert Repo.aggregate(Report, :count) == 5
  end

  test "POST as a banned user redirects with the ban flash", %{conn: conn} do
    %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

    conn = post(conn, ~p"/images/999999999/reports", %{})

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
  end

  test "GET new renders the report form without a fingerprint", %{conn: conn} do
    image = image_fixture()

    conn = get(without_fingerprint(conn), ~p"/images/#{image}/reports/new")

    assert html_response(conn, 200) =~ "Reporting Image - Derpibooru"
  end

  test "POST without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
    image = image_fixture()

    conn =
      post(without_fingerprint(conn), ~p"/images/#{image}/reports", %{
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
