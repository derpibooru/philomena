defmodule PhilomenaWeb.DuplicateReportControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # Show and create are public. The index is a staff review surface and is
  # authorized by the context even though its route lives in the public scope.

  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures
  import Philomena.DuplicateReportsFixtures

  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.Repo

  describe "GET /duplicate_reports" do
    test "an empty dq parameter uses the default report query", %{conn: conn} do
      conn = log_in_user(conn, moderator_user_fixture())
      source = image_fixture()
      target = image_fixture()
      duplicate_report_fixture(source, target)

      conn = get(conn, ~p"/duplicate_reports?dq=")

      assert html_response(conn, 200) =~ ~p"/images/#{source}"
    end

    test "lists open/claimed reports for moderators", %{conn: conn} do
      conn = log_in_user(conn, moderator_user_fixture())
      source = image_fixture()
      target = image_fixture()
      dr = duplicate_report_fixture(source, target)

      conn = get(conn, ~p"/duplicate_reports")
      response = html_response(conn, 200)

      assert response =~ "Duplicate Reports - Derpibooru"
      assert response =~ ~p"/images/#{source}"
      assert response =~ ~p"/images/#{target}"
      _ = dr
    end

    test "permits anonymous users", %{conn: conn} do
      conn = get(conn, ~p"/duplicate_reports")
      assert html_response(conn, 200)
    end

    test "renders merge and state controls for DuplicateReport assistants", %{conn: conn} do
      conn = log_in_user(conn, role_assistant_fixture("DuplicateReport"))
      source = image_fixture()
      target = image_fixture()
      report = duplicate_report_fixture(source, target)

      response = html_response(get(conn, ~p"/duplicate_reports"), 200)

      assert response =~ "Keep Source"
      assert response =~ "Keep Target"
      assert response =~ "Claim"
      assert response =~ "Reject"
      assert response =~ ~p"/duplicate_reports/#{report}/accept_reverse"
      assert response =~ ~p"/duplicate_reports/#{report}/accept"
      assert response =~ ~p"/duplicate_reports/#{report}/claim"
      assert response =~ ~p"/duplicate_reports/#{report}/reject"
    end

    test "offers no reject control on an accepted report", %{conn: conn} do
      conn = log_in_user(conn, moderator_user_fixture())
      report = duplicate_report_fixture(image_fixture(), image_fixture())
      report |> Ecto.Changeset.change(state: "accepted") |> Repo.update!()

      response =
        html_response(get(conn, ~p"/duplicate_reports?#{[dq: [states: ["accepted"]]]}"), 200)

      assert response =~ "Accepted"
      refute response =~ ~p"/duplicate_reports/#{report}/reject"
    end

    test "hides merge and state controls from regular users", %{conn: conn} do
      conn = log_in_user(conn, confirmed_user_fixture())
      source = image_fixture()
      target = image_fixture()
      report = duplicate_report_fixture(source, target)

      response = html_response(get(conn, ~p"/duplicate_reports"), 200)

      refute response =~ "Keep Source"
      refute response =~ "Keep Target"
      refute response =~ ~p"/duplicate_reports/#{report}/claim"
      refute response =~ ~p"/duplicate_reports/#{report}/reject"
    end

    test "renders modifier and reporter identities for DuplicateReport assistants", %{conn: conn} do
      assistant = role_assistant_fixture("DuplicateReport", %{name: "Review Assistant"})
      reporter = confirmed_user_fixture(%{name: "Report Submitter"})
      source = image_fixture()
      target = image_fixture()
      report = duplicate_report_fixture(source, target, reporter)
      conn = log_in_user(conn, assistant)

      claim_conn = post(conn, ~p"/duplicate_reports/#{report}/claim")
      response = html_response(claim_conn, 200)

      assert response =~ "by Review Assistant"
      assert response =~ "Report Submitter"
    end

    test "the default view omits rejected/accepted reports", %{conn: conn} do
      conn = log_in_user(conn, moderator_user_fixture())
      source = image_fixture()
      target = image_fixture()
      dr = duplicate_report_fixture(source, target)

      dr
      |> Ecto.Changeset.change(state: "rejected")
      |> Repo.update!()

      conn = get(conn, ~p"/duplicate_reports")
      response = html_response(conn, 200)

      # NOTE: index defaults to the "open"/"claimed" states, so a rejected
      # report is hidden unless ?states[] asks for it explicitly.
      refute response =~ ~p"/images/#{source}"

      conn = get(conn, ~p"/duplicate_reports?#{[dq: [states: ["rejected"]]]}")
      assert html_response(conn, 200) =~ ~p"/images/#{source}"
    end

    test "an unrecognized state param falls back to nothing matching", %{conn: conn} do
      conn = log_in_user(conn, moderator_user_fixture())
      source = image_fixture()
      target = image_fixture()
      duplicate_report_fixture(source, target)

      # NOTE: index filters the requested states against a fixed allowlist; a
      # bogus state leaves an empty list, so no reports render at all.
      conn = get(conn, ~p"/duplicate_reports?#{[dq: [states: ["bogus"]]]}")
      response = html_response(conn, 200)

      assert response =~ "Duplicate Reports - Derpibooru"
      refute response =~ ~p"/images/#{source}"
    end
  end

  describe "GET /duplicate_reports/:id" do
    test "shows a report to anonymous users", %{conn: conn} do
      source = image_fixture()
      target = image_fixture()
      dr = duplicate_report_fixture(source, target)

      conn = get(conn, ~p"/duplicate_reports/#{dr}")
      response = html_response(conn, 200)

      # NOTE: the show page renders an SVG diff of the two images (not plain
      # /images/N links), so pin the title and the source/target caption.
      assert response =~ "Showing Duplicate Report - Derpibooru"
      assert response =~ "Left is source, right is target"
      _ = {source, target}
    end

    test "an unknown id redirects with the not-found flash", %{conn: conn} do
      conn = get(conn, ~p"/duplicate_reports/#{123_456_789}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "a non-integer id redirects with the not-found flash", %{conn: conn} do
      conn = get(conn, ~p"/duplicate_reports/not-an-integer")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end

  describe "POST /duplicate_reports" do
    test "an anonymous visitor can create a report", %{conn: conn} do
      source = image_fixture()
      target = image_fixture()

      conn =
        post(conn, ~p"/duplicate_reports", %{
          "duplicate_report" => %{
            "image_id" => source.id,
            "duplicate_of_image_id" => target.id,
            "reason" => "same image"
          }
        })

      assert redirected_to(conn) == ~p"/images/#{source}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "created successfully"

      dr = Repo.get_by!(DuplicateReport, image_id: source.id, duplicate_of_image_id: target.id)
      assert dr.state == "open"
      assert dr.user_id == nil
    end

    test "a logged-in user is recorded as the reporter", %{conn: conn} do
      user = confirmed_user_fixture()
      conn = log_in_user(conn, user)
      source = image_fixture()
      target = image_fixture()

      conn =
        post(conn, ~p"/duplicate_reports", %{
          "duplicate_report" => %{
            "image_id" => source.id,
            "duplicate_of_image_id" => target.id
          }
        })

      assert redirected_to(conn) == ~p"/images/#{source}"

      dr = Repo.get_by!(DuplicateReport, image_id: source.id)
      assert dr.user_id == user.id
    end

    test "a banned user is rejected before submission", %{conn: conn} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})
      source = image_fixture()
      target = image_fixture()

      conn =
        post(conn, ~p"/duplicate_reports", %{
          "duplicate_report" => %{
            "image_id" => source.id,
            "duplicate_of_image_id" => target.id
          }
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
      refute Repo.exists?(DuplicateReport)
    end

    test "reporting an image as a duplicate of itself fails validation", %{conn: conn} do
      source = image_fixture()

      conn =
        post(conn, ~p"/duplicate_reports", %{
          "duplicate_report" => %{
            "image_id" => source.id,
            "duplicate_of_image_id" => source.id
          }
        })

      assert redirected_to(conn) == ~p"/images/#{source}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Failed to submit duplicate report"
      refute Repo.exists?(DuplicateReport)
    end

    # NOTE: create now loads images with a parse-guarded Repo.get; an unknown (or
    # non-integer) source image_id has nowhere to redirect back to, so it takes
    # the NotFoundPlug path rather than raising.
    test "an unknown source image id redirects with the not-found flash", %{conn: conn} do
      target = image_fixture()

      conn =
        post(conn, ~p"/duplicate_reports", %{
          "duplicate_report" => %{
            "image_id" => 123_456_789,
            "duplicate_of_image_id" => target.id
          }
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "an unknown target image id redirects with the not-found flash",
         %{conn: conn} do
      source = image_fixture()

      conn =
        post(conn, ~p"/duplicate_reports", %{
          "duplicate_report" => %{
            "image_id" => source.id,
            "duplicate_of_image_id" => 123_456_789
          }
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
      refute Repo.exists?(DuplicateReport)
    end

    # NOTE: a request without the duplicate_report param takes the fallback
    # create/2 clause and answers via NotFoundPlug.
    test "a missing duplicate_report param redirects with the not-found flash", %{conn: conn} do
      conn = post(conn, ~p"/duplicate_reports", %{})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      source = image_fixture()

      conn =
        post(without_fingerprint(conn), ~p"/duplicate_reports", %{
          "duplicate_report" => %{
            "image_id" => source.id,
            "duplicate_of_image_id" => image_fixture().id
          }
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.get_by(DuplicateReport, image_id: source.id)
    end
  end
end
