defmodule PhilomenaWeb.DuplicateReport.ClaimControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ImagesFixtures
  import Philomena.DuplicateReportsFixtures

  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.Repo

  defp claimed_report(mod) do
    dr = duplicate_report_fixture(image_fixture(), image_fixture())

    dr
    |> Ecto.Changeset.change(state: "claimed", modifier_id: mod.id)
    |> Repo.update!()
  end

  describe "POST /duplicate_reports/:duplicate_report_id/claim" do
    test "is rejected for anonymous users", %{conn: conn} do
      dr = duplicate_report_fixture(image_fixture(), image_fixture())

      conn = post(conn, ~p"/duplicate_reports/#{dr}/claim")

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "is rejected for regular users", %{conn: conn} do
      conn = log_in_user(conn, Philomena.UsersFixtures.confirmed_user_fixture())
      dr = duplicate_report_fixture(image_fixture(), image_fixture())

      conn = post(conn, ~p"/duplicate_reports/#{dr}/claim")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
    end

    test "a moderator claims the report", %{conn: conn} do
      %{conn: conn, user: mod} = register_and_log_in_moderator(%{conn: conn})
      dr = duplicate_report_fixture(image_fixture(), image_fixture())

      conn = post(conn, ~p"/duplicate_reports/#{dr}/claim")

      assert html_response(conn, 200)

      dr = Repo.get!(DuplicateReport, dr.id)
      assert dr.state == "claimed"
      assert dr.modifier_id == mod.id
    end

    test "an unknown report id takes the not-found redirect", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/duplicate_reports/#{123_456_789}/claim")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "a non-integer report id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/duplicate_reports/not-an-integer/claim")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end

  describe "DELETE /duplicate_reports/:duplicate_report_id/claim" do
    test "is rejected for anonymous users", %{conn: conn} do
      dr = duplicate_report_fixture(image_fixture(), image_fixture())

      conn = delete(conn, ~p"/duplicate_reports/#{dr}/claim")

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "is rejected for regular users", %{conn: conn} do
      conn = log_in_user(conn, Philomena.UsersFixtures.confirmed_user_fixture())
      dr = duplicate_report_fixture(image_fixture(), image_fixture())

      conn = delete(conn, ~p"/duplicate_reports/#{dr}/claim")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
    end

    test "a moderator releases their claim", %{conn: conn} do
      %{conn: conn, user: mod} = register_and_log_in_moderator(%{conn: conn})
      dr = claimed_report(mod)

      conn = delete(conn, ~p"/duplicate_reports/#{dr}/claim")

      assert html_response(conn, 200)

      dr = Repo.get!(DuplicateReport, dr.id)
      assert dr.state == "open"
      assert dr.modifier_id == nil
    end

    test "an unknown report id takes the not-found redirect", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = delete(conn, ~p"/duplicate_reports/#{123_456_789}/claim")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "a non-integer report id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = delete(conn, ~p"/duplicate_reports/not-an-integer/claim")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end
end
