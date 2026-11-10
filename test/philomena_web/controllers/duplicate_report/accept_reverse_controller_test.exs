defmodule PhilomenaWeb.DuplicateReport.AcceptReverseControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # Accepting in reverse rejects the original report and merges the
  # *target* image into the source instead.

  import Philomena.ImagesFixtures
  import Philomena.DuplicateReportsFixtures

  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.Images.Image
  alias Philomena.Repo

  describe "POST /duplicate_reports/:duplicate_report_id/accept_reverse" do
    test "is rejected for anonymous users", %{conn: conn} do
      source = image_fixture()
      target = image_fixture()
      dr = duplicate_report_fixture(source, target)

      conn = post(conn, ~p"/duplicate_reports/#{dr}/accept_reverse")

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "is rejected for regular users", %{conn: conn} do
      conn = log_in_user(conn, Philomena.UsersFixtures.confirmed_user_fixture())
      source = image_fixture()
      target = image_fixture()
      dr = duplicate_report_fixture(source, target)

      conn = post(conn, ~p"/duplicate_reports/#{dr}/accept_reverse")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
    end

    test "a moderator reverses the report and merges the target image", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      source = image_fixture()
      target = image_fixture()
      dr = duplicate_report_fixture(source, target)

      conn = post(conn, ~p"/duplicate_reports/#{dr}/accept_reverse")

      assert html_response(conn, 200)

      # The original report is rejected, and the *target* image becomes the
      # duplicate that gets hidden (merged into the source).
      dr = Repo.get!(DuplicateReport, dr.id)
      assert dr.state == "rejected"

      target = Repo.get!(Image, target.id)
      assert target.hidden_from_users == true
      assert target.duplicate_id == source.id
    end

    test "an unknown report id takes the not-found redirect", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/duplicate_reports/#{123_456_789}/accept_reverse")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "a non-integer report id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/duplicate_reports/not-an-integer/accept_reverse")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end
end
