defmodule PhilomenaWeb.Image.Comment.ReportControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Ecto.Query
  import Philomena.CommentsFixtures
  import Philomena.ImagesFixtures
  import Philomena.RulesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Reports.Report
  alias Philomena.Repo

  test "GET new renders the report form for anonymous users", %{conn: conn} do
    image = image_fixture()
    comment = comment_fixture(image, nil, %{"body" => "Reportable comment body"})

    response =
      html_response(get(conn, ~p"/images/#{image}/comments/#{comment}/reports/new"), 200)

    # the form does not render the comment body, only the shared report
    # boilerplate
    assert response =~ "Reporting Comment - Derpibooru"
  end

  test "GET new for an unknown comment redirects to / with the not-found flash",
       %{conn: conn} do
    image = image_fixture()

    conn = get(conn, ~p"/images/#{image}/comments/999999999/reports/new")

    assert redirected_to(conn) == "/"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
             "Couldn't find what you were looking for!"
  end

  test "GET and POST reject a comment through a different route image", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    image = image_fixture()
    other_image = image_fixture()
    comment = comment_fixture(image)
    rule = rule_fixture()

    get_conn = get(conn, ~p"/images/#{other_image}/comments/#{comment}/reports/new")
    assert redirected_to(get_conn) == "/"

    post_conn =
      conn
      |> recycle()
      |> post(~p"/images/#{other_image}/comments/#{comment}/reports", %{
        "report" => %{
          "reason" => "Wrong parent",
          "rule_id" => rule.id,
          "user_agent" => "Test Browser/1.0"
        }
      })

    assert redirected_to(post_conn) == "/"
    assert Repo.aggregate(Report, :count) == 0
  end

  test "POST as a logged-in user creates the report and redirects to /reports", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    image = image_fixture()
    comment = comment_fixture(image, confirmed_user_fixture())
    rule = rule_fixture()

    # the form embeds the browser's User-Agent as a hidden field, and the
    # changeset requires it to be non-empty
    conn =
      post(conn, ~p"/images/#{image}/comments/#{comment}/reports", %{
        "report" => %{
          "reason" => "Test comment report",
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
          where: r.comment_id == ^comment.id
      )

    assert report.user_id == user.id
  end

  test "POST anonymously creates the report and redirects to /", %{conn: conn} do
    image = image_fixture()
    comment = comment_fixture(image)
    rule = rule_fixture()

    conn =
      post(conn, ~p"/images/#{image}/comments/#{comment}/reports", %{
        "report" => %{
          "reason" => "Anonymous comment report",
          "rule_id" => rule.id,
          "user_agent" => "Test Browser/1.0"
        }
      })

    assert redirected_to(conn) == "/"

    assert Repo.exists?(
             from r in Report,
               where: r.comment_id == ^comment.id
           )
  end

  test "POST with a blank reason re-renders the report form", %{conn: conn} do
    # NOTE: the create failure now renders new.html through the shared
    # PhilomenaWeb.ReportView (200) rather than raising on a missing view.
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    image = image_fixture()
    comment = comment_fixture(image)
    rule = rule_fixture()

    conn =
      post(conn, ~p"/images/#{image}/comments/#{comment}/reports", %{
        "report" => %{
          "reason" => "",
          "rule_id" => rule.id,
          "user_agent" => "Test Browser/1.0"
        }
      })

    assert html_response(conn, 200) =~ "Submit a report"
    assert Repo.aggregate(Report, :count) == 0
  end

  test "POST as a banned user redirects with the ban flash", %{conn: conn} do
    %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

    conn = post(conn, ~p"/images/999999999/comments/999999999/reports", %{})

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
  end

  test "GET new renders the report form without a fingerprint", %{conn: conn} do
    image = image_fixture()
    comment = comment_fixture(image)

    conn = get(without_fingerprint(conn), ~p"/images/#{image}/comments/#{comment}/reports/new")

    assert html_response(conn, 200) =~ "Reporting Comment - Derpibooru"
  end

  test "POST without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
    image = image_fixture()
    comment = comment_fixture(image)

    conn =
      post(without_fingerprint(conn), ~p"/images/#{image}/comments/#{comment}/reports", %{
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
