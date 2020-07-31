defmodule PhilomenaWeb.SessionControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures

  setup do
    %{user: confirmed_user_fixture()}
  end

  describe "GET /sessions/new" do
    test "renders log in page", %{conn: conn} do
      conn = get(conn, Routes.session_path(conn, :new))
      html_response(conn, 200)
    end

    test "redirects if already logged in", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> get(Routes.session_path(conn, :new))
      assert redirected_to(conn) == "/"
    end
  end

  describe "POST /sessions" do
    test "logs the user in", %{conn: conn, user: user} do
      conn =
        post(conn, Routes.session_path(conn, :create), %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) =~ "/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/registrations/edit")
      response = html_response(conn, 200)
      assert response =~ user.email
      assert response =~ "Settings</a>"
      assert response =~ "Logout</a>"
    end

    test "logs the user in with remember me", %{conn: conn, user: user} do
      conn =
        post(conn, Routes.session_path(conn, :create), %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["user_remember_me"]
      assert redirected_to(conn) =~ "/"
    end

    test "emits error message with invalid credentials", %{conn: conn, user: user} do
      conn =
        post(conn, Routes.session_path(conn, :create), %{
          "user" => %{"email" => user.email, "password" => "invalid_password"}
        })

      response = html_response(conn, 200)
      assert response =~ "Invalid email or password"
    end
  end

  describe "DELETE /sessions" do
    test "logs the user out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete(Routes.session_path(conn, :delete))
      assert redirected_to(conn) == "/"
      refute get_session(conn, :user_token)
      assert get_flash(conn, :info) =~ "Logged out successfully"
    end
  end
end
