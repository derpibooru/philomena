defmodule PhilomenaWeb.Registration.TotpControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures

  alias Philomena.Users
  alias Philomena.Users.User
  alias Philomena.Repo

  defp put_totp_secret(user) do
    user |> User.create_totp_secret_changeset() |> Repo.update!()
  end

  defp valid_totp_code(user), do: :pot.totp(User.totp_secret(user))

  describe "GET /registrations/totp/edit" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      conn = get(conn, ~p"/registrations/totp/edit")
      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "generates a secret and redirects back on first visit", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/registrations/totp/edit")

      assert redirected_to(conn) == ~p"/registrations/totp/edit"
      assert Users.fetch_user_for_worker!(user.id).encrypted_otp_secret
    end

    test "renders the setup page once a secret exists", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      put_totp_secret(user)

      conn = get(conn, ~p"/registrations/totp/edit")

      response = html_response(conn, 200)
      assert response =~ "Two Factor Authentication - Derpibooru"
      assert response =~ "data:image/png;base64,"
    end

    test "redirects a TOTP user who has not passed the second factor", %{conn: conn} do
      user = totp_user_fixture()
      conn = conn |> log_in_user(user) |> get(~p"/registrations/totp/edit")
      assert redirected_to(conn) == ~p"/sessions/totp/new"
    end
  end

  describe "PATCH /registrations/totp (enabling)" do
    setup :register_and_log_in_user

    test "enables TOTP with a valid code and redirects", %{conn: conn, user: user} do
      user = put_totp_secret(user)

      # NOTE: the success branch now ends on the redirect conn (the reindex
      # happens before it), so enabling 2FA redirects cleanly instead of raising.
      conn =
        patch(conn, ~p"/registrations/totp", %{
          "user" => %{
            "current_password" => valid_user_password(),
            "twofactor_token" => valid_totp_code(user)
          }
        })

      assert redirected_to(conn) == ~p"/registrations/totp/edit"

      user = Users.fetch_user_for_worker!(user.id)
      assert user.otp_required_for_login
      assert length(user.otp_backup_codes) == 10
    end

    test "re-renders on a wrong password", %{conn: conn, user: user} do
      user = put_totp_secret(user)

      conn =
        patch(conn, ~p"/registrations/totp", %{
          "user" => %{
            "current_password" => "wrong password",
            "twofactor_token" => valid_totp_code(user)
          }
        })

      assert html_response(conn, 200) =~ "data:image/png;base64,"
      refute Users.fetch_user_for_worker!(user.id).otp_required_for_login
    end

    test "re-renders on an invalid TOTP code", %{conn: conn, user: user} do
      put_totp_secret(user)

      # NOTE: an invalid code now re-renders the setup page (200) with a
      # changeset error; the backup-code check safely returns false for a user
      # who is still enabling 2FA (otp_backup_codes: nil).
      conn =
        patch(conn, ~p"/registrations/totp", %{
          "user" => %{
            "current_password" => valid_user_password(),
            "twofactor_token" => "not a code"
          }
        })

      assert html_response(conn, 200) =~ "data:image/png;base64,"
      refute Users.fetch_user_for_worker!(user.id).otp_required_for_login
    end
  end

  describe "PATCH /registrations/totp (disabling)" do
    test "disables TOTP with a valid code and redirects", %{conn: conn} do
      user = totp_user_fixture()
      conn = log_in_totp_user(conn, user)

      conn =
        patch(conn, ~p"/registrations/totp", %{
          "user" => %{
            "current_password" => valid_user_password(),
            "twofactor_token" => valid_totp_code(user)
          }
        })

      assert redirected_to(conn) == ~p"/registrations/totp/edit"

      user = Users.fetch_user_for_worker!(user.id)
      refute user.otp_required_for_login
      assert user.otp_backup_codes == []
      refute user.encrypted_otp_secret
    end
  end

  describe "PUT /registrations/totp" do
    setup :register_and_log_in_user

    test "behaves like PATCH", %{conn: conn, user: user} do
      user = put_totp_secret(user)

      conn =
        put(conn, ~p"/registrations/totp", %{
          "user" => %{
            "current_password" => "wrong password",
            "twofactor_token" => valid_totp_code(user)
          }
        })

      assert html_response(conn, 200) =~ "data:image/png;base64,"
    end
  end
end
