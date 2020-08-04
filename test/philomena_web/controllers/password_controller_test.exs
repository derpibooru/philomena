defmodule PhilomenaWeb.PasswordControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  alias Philomena.Users
  alias Philomena.Repo
  import Philomena.UsersFixtures

  setup do
    %{user: confirmed_user_fixture()}
  end

  describe "GET /passwords/new" do
    test "renders the reset password page", %{conn: conn} do
      conn = get(conn, Routes.password_path(conn, :new))
      html_response(conn, 200)
    end
  end

  describe "POST /passwords" do
    @tag :capture_log
    test "sends a new reset password token", %{conn: conn, user: user} do
      conn =
        post(conn, Routes.password_path(conn, :create), %{
          "user" => %{"email" => user.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.get_by!(Users.UserToken, user_id: user.id).context == "reset_password"
    end

    test "does not send reset password token if email is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.password_path(conn, :create), %{
          "user" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.all(Users.UserToken) == []
    end
  end

  describe "GET /passwords/:token" do
    setup %{user: user} do
      token =
        extract_user_token(fn url ->
          Users.deliver_user_reset_password_instructions(user, url)
        end)

      %{token: token}
    end

    test "renders reset password", %{conn: conn, token: token} do
      conn = get(conn, Routes.password_path(conn, :edit, token))
      html_response(conn, 200)
    end

    test "does not render reset password with invalid token", %{conn: conn} do
      conn = get(conn, Routes.password_path(conn, :edit, "oops"))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Reset password link is invalid or it has expired"
    end
  end

  describe "PUT /passwords/:token" do
    setup %{user: user} do
      token =
        extract_user_token(fn url ->
          Users.deliver_user_reset_password_instructions(user, url)
        end)

      %{token: token}
    end

    test "resets password once", %{conn: conn, user: user, token: token} do
      conn =
        put(conn, Routes.password_path(conn, :update, token), %{
          "user" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(conn) == Routes.session_path(conn, :new)
      refute get_session(conn, :user_token)
      assert get_flash(conn, :info) =~ "Password reset successfully"
      assert Users.get_user_by_email_and_password(user.email, "new valid password", & &1)
    end

    test "does not reset password on invalid data", %{conn: conn, token: token} do
      conn =
        put(conn, Routes.password_path(conn, :update, token), %{
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      response = html_response(conn, 200)
      assert response =~ "should be at least 12 character"
      assert response =~ "does not match password"
    end

    test "does not reset password with invalid token", %{conn: conn} do
      conn = put(conn, Routes.password_path(conn, :update, "oops"))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Reset password link is invalid or it has expired"
    end
  end
end
