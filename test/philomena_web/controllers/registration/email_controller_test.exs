defmodule PhilomenaWeb.Registration.EmailControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  alias Philomena.Users
  import Philomena.UsersFixtures

  setup :register_and_log_in_user

  describe "POST /registrations/email" do
    @tag :capture_log
    test "updates the user email", %{conn: conn, user: user} do
      conn =
        post(conn, Routes.registration_email_path(conn, :create), %{
          "current_password" => valid_user_password(),
          "user" => %{"email" => unique_user_email()}
        })

      assert redirected_to(conn) == Routes.registration_path(conn, :edit)
      assert get_flash(conn, :info) =~ "A link to confirm your email"
      assert Users.get_user_by_email(user.email)
    end

    test "does not update email on invalid data", %{conn: conn} do
      conn =
        post(conn, Routes.registration_email_path(conn, :create), %{
          "current_password" => "invalid",
          "user" => %{"email" => "with spaces"}
        })

      assert get_flash(conn, :error) =~ "Failed to update email"
    end
  end

  describe "GET /registrations/email/:token" do
    setup %{user: user} do
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Users.deliver_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{token: token, email: email}
    end

    test "updates the user email once", %{conn: conn, user: user, token: token, email: email} do
      conn = get(conn, Routes.registration_email_path(conn, :show, token))
      assert redirected_to(conn) == Routes.registration_path(conn, :edit)
      assert get_flash(conn, :info) =~ "Email changed successfully"
      refute Users.get_user_by_email(user.email)
      assert Users.get_user_by_email(email)

      conn = get(conn, Routes.registration_email_path(conn, :show, token))
      assert redirected_to(conn) == Routes.registration_path(conn, :edit)
      assert get_flash(conn, :error) =~ "Email change link is invalid or it has expired"
    end

    test "does not update email with invalid token", %{conn: conn, user: user} do
      conn = get(conn, Routes.registration_email_path(conn, :show, "oops"))
      assert redirected_to(conn) == Routes.registration_path(conn, :edit)
      assert get_flash(conn, :error) =~ "Email change link is invalid or it has expired"
      assert Users.get_user_by_email(user.email)
    end

    test "redirects if user is not logged in", %{token: token} do
      conn = build_conn()
      conn = get(conn, Routes.registration_email_path(conn, :show, token))
      assert redirected_to(conn) == Routes.session_path(conn, :new)
    end
  end
end
