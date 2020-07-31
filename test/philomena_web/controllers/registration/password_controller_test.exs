defmodule PhilomenaWeb.Registration.PasswordControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  alias Philomena.Users
  import Philomena.UsersFixtures

  setup :register_and_log_in_user

  describe "PUT /registrations/password" do
    test "updates the user password and resets tokens", %{conn: conn, user: user} do
      new_password_conn =
        put(conn, Routes.registration_password_path(conn, :update), %{
          "current_password" => valid_user_password(),
          "user" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(new_password_conn) == Routes.registration_path(conn, :edit)
      assert get_session(new_password_conn, :user_token) != get_session(conn, :user_token)
      assert get_flash(new_password_conn, :info) =~ "Password updated successfully"
      assert Users.get_user_by_email_and_password(user.email, "new valid password", & &1)
    end

    test "does not update password on invalid data", %{conn: conn} do
      old_password_conn =
        put(conn, Routes.registration_password_path(conn, :update), %{
          "current_password" => "invalid",
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert redirected_to(old_password_conn) == Routes.registration_path(conn, :edit)
      assert get_flash(old_password_conn, :error) =~ "Failed to update password"
      assert get_session(old_password_conn, :user_token) == get_session(conn, :user_token)
    end
  end
end
