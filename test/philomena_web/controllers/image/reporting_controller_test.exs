defmodule PhilomenaWeb.Image.ReportingControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ImagesFixtures

  alias Phoenix.Flash

  describe "GET /images/:image_id/reporting" do
    test "renders the reporting partial without a layout for anonymous users", %{conn: conn} do
      image = image_fixture()

      conn = get(conn, ~p"/images/#{image}/reporting")
      response = html_response(conn, 200)

      assert response =~ "General reporting"
      assert response =~ "log in"
      refute response =~ "Derpibooru"
    end

    test "renders the duplicate report form for logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()

      conn = get(conn, ~p"/images/#{image}/reporting")
      response = html_response(conn, 200)

      assert response =~ "General reporting"
      refute response =~ "You must"
    end

    test "rejects a banned user with the same prerequisite as submission", %{conn: conn} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})
      image = image_fixture()

      conn = get(conn, ~p"/images/#{image}/reporting")

      assert redirected_to(conn) == "/"
      assert Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
    end

    test "redirects to / for a hidden image as anonymous", %{conn: conn} do
      image = image_fixture(hidden_from_users: true)

      conn = get(conn, ~p"/images/#{image}/reporting")

      assert redirected_to(conn) == "/"
      assert Flash.get(conn.assigns.flash, :error) =~ "You can't access that page."
    end

    test "redirects to / for an unknown image id", %{conn: conn} do
      conn = get(conn, ~p"/images/999999999/reporting")

      assert redirected_to(conn) == "/"
      assert Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "renders the duplicate report form without a fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()

      conn = get(without_fingerprint(conn), ~p"/images/#{image}/reporting")

      assert html_response(conn, 200) =~ "General reporting"
    end
  end
end
