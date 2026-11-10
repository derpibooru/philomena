defmodule PhilomenaWeb.Registration.PasswordControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  alias Philomena.Users
  alias Phoenix.Flash
  import Philomena.UsersFixtures

  setup :register_and_log_in_user

  describe "PUT /registrations/password" do
    test "updates the user password and resets tokens", %{conn: conn, user: user} do
      new_password_conn =
        put(conn, ~p"/registrations/password", %{
          "current_password" => valid_user_password(),
          "user" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(new_password_conn) == ~p"/registrations/edit"
      assert get_session(new_password_conn, :user_token) != get_session(conn, :user_token)
      assert Flash.get(new_password_conn.assigns.flash, :info) =~ "Password updated successfully"

      assert {:ok, _} =
               Users.fetch_user_by_email_and_password(user.email, "new valid password", & &1)
    end

    test "does not update password on invalid data", %{conn: conn} do
      old_password_conn =
        put(conn, ~p"/registrations/password", %{
          "current_password" => "invalid",
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert redirected_to(old_password_conn) == ~p"/registrations/edit"
      assert Flash.get(old_password_conn.assigns.flash, :error) =~ "Failed to update password"
      assert get_session(old_password_conn, :user_token) == get_session(conn, :user_token)
    end

    test "invalidates all previous session tokens on success", %{conn: conn, user: user} do
      old_token = get_session(conn, :user_token)

      put(conn, ~p"/registrations/password", %{
        "current_password" => valid_user_password(),
        "user" => %{
          "password" => "new valid password",
          "password_confirmation" => "new valid password"
        }
      })

      refute Users.get_user_by_session_token(old_token)

      assert {:ok, _} =
               Users.fetch_user_by_email_and_password(user.email, "new valid password", & &1)
    end
  end

  describe "PATCH /registrations/password" do
    test "behaves like PUT", %{conn: conn, user: user} do
      conn =
        patch(conn, ~p"/registrations/password", %{
          "current_password" => valid_user_password(),
          "user" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(conn) == ~p"/registrations/edit"

      assert {:ok, _} =
               Users.fetch_user_by_email_and_password(user.email, "new valid password", & &1)
    end

    test "raises without a current_password param", %{conn: conn} do
      assert_raise Phoenix.ActionClauseError, fn ->
        patch(conn, ~p"/registrations/password", %{
          "user" => %{"password" => "new valid password"}
        })
      end
    end

    test "redirects anonymous users to the login page" do
      conn = build_conn()

      conn =
        patch(conn, ~p"/registrations/password", %{
          "current_password" => "irrelevant",
          "user" => %{"password" => "new valid password"}
        })

      assert redirected_to(conn) == ~p"/sessions/new"
    end
  end
end
