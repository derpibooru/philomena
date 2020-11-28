defmodule PhilomenaWeb.RegistrationControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures

  describe "GET /registrations/new" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, Routes.registration_path(conn, :new))
      html_response(conn, 200)
    end

    test "redirects if already logged in", %{conn: conn} do
      conn =
        conn |> log_in_user(confirmed_user_fixture()) |> get(Routes.registration_path(conn, :new))

      assert redirected_to(conn) == "/"
    end
  end

  describe "POST /registrations" do
    @tag :capture_log
    test "creates account but doesn't log the user in", %{conn: conn} do
      email = unique_user_email()

      conn =
        post(conn, Routes.registration_path(conn, :create), %{
          "user" => %{"name" => email, "email" => email, "password" => valid_user_password()}
        })

      assert redirected_to(conn) =~ "/"

      conn = get(conn, "/sessions/new")
      html_response(conn, 200)
      assert get_flash(conn, :info) =~ "email for confirmation instructions"
    end

    test "render errors for invalid data", %{conn: conn} do
      conn =
        post(conn, Routes.registration_path(conn, :create), %{
          "user" => %{"email" => "with spaces", "password" => "too short"}
        })

      response = html_response(conn, 200)
      assert response =~ "must be valid (e.g., user@example.com)"
      assert response =~ "should be at least 12 character"
    end
  end

  describe "GET /registration/edit" do
    setup :register_and_log_in_user

    test "renders settings page", %{conn: conn} do
      conn = get(conn, Routes.registration_path(conn, :edit))
      response = html_response(conn, 200)
      assert response =~ "Settings"
    end

    test "redirects if user is not logged in" do
      conn = build_conn()
      conn = get(conn, Routes.registration_path(conn, :edit))
      assert redirected_to(conn) == Routes.session_path(conn, :new)
    end
  end
end
