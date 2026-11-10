defmodule PhilomenaWeb.Conversation.ReportControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Ecto.Query
  import Philomena.ConversationsFixtures
  import Philomena.RulesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Reports.Report
  alias Philomena.Repo

  test "anonymous requests redirect to the login page", %{conn: conn} do
    for request <- [
          get(conn, ~p"/conversations/dummy-slug/reports/new"),
          post(conn, ~p"/conversations/dummy-slug/reports", %{})
        ] do
      assert redirected_to(request) == ~p"/sessions/new"

      assert Phoenix.Flash.get(request.assigns.flash, :error) ==
               "You must log in to access this page."
    end
  end

  test "GET new as a participant renders the report form", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    conversation = conversation_fixture(confirmed_user_fixture(), user)

    response = html_response(get(conn, ~p"/conversations/#{conversation}/reports/new"), 200)

    # the form does not render the conversation title, only the shared
    # report boilerplate
    assert response =~ "Reporting Conversation - Derpibooru"
  end

  test "GET new as a non-participant redirects to / with the authorization flash",
       %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    conversation = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())

    conn = get(conn, ~p"/conversations/#{conversation}/reports/new")

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
  end

  test "POST as a participant creates the report and redirects to /reports", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    conversation = conversation_fixture(confirmed_user_fixture(), user)
    rule = rule_fixture()

    # the form embeds the browser's User-Agent as a hidden field, and the
    # changeset requires it to be non-empty
    conn =
      post(conn, ~p"/conversations/#{conversation}/reports", %{
        "report" => %{
          "reason" => "Test conversation report",
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
          where: r.conversation_id == ^conversation.id
      )

    assert report.user_id == user.id
    assert report.reason == "Test conversation report"
    assert report.state == "open"
  end

  test "POST with a blank reason re-renders the report form", %{conn: conn} do
    # NOTE: the create failure now renders new.html through the shared
    # PhilomenaWeb.ReportView (200) rather than raising on a missing view.
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    conversation = conversation_fixture(confirmed_user_fixture(), user)
    rule = rule_fixture()

    conn =
      post(conn, ~p"/conversations/#{conversation}/reports", %{
        "report" => %{
          "reason" => "",
          "rule_id" => rule.id,
          "user_agent" => "Test Browser/1.0"
        }
      })

    assert html_response(conn, 200) =~ "Submit a report"
    assert Repo.aggregate(Report, :count) == 0
  end

  test "POST with more than 5 open reports redirects to / with the limit flash",
       %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    conversation = conversation_fixture(confirmed_user_fixture(), user)
    rule = rule_fixture()

    for _ <- 1..5 do
      Philomena.ReportsFixtures.report_fixture(user, conversation_id: conversation.id)
    end

    conn =
      post(conn, ~p"/conversations/#{conversation}/reports", %{
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

  test "POST as a non-participant redirects to / with the authorization flash", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    conversation = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())
    rule = rule_fixture()

    conn =
      post(conn, ~p"/conversations/#{conversation}/reports", %{
        "report" => %{"reason" => "Should not appear", "rule_id" => rule.id}
      })

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    assert Repo.aggregate(Report, :count) == 0
  end

  test "POST as a banned user redirects with the ban flash", %{conn: conn} do
    %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

    conn = post(conn, ~p"/conversations/dummy-slug/reports", %{})

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
  end

  test "GET new renders the report form without a fingerprint", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    conversation = conversation_fixture(confirmed_user_fixture(), user)

    conn = get(without_fingerprint(conn), ~p"/conversations/#{conversation}/reports/new")

    assert html_response(conn, 200) =~ "Reporting Conversation - Derpibooru"
  end

  test "POST without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    conversation = conversation_fixture(confirmed_user_fixture(), user)

    conn =
      post(without_fingerprint(conn), ~p"/conversations/#{conversation}/reports", %{
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
