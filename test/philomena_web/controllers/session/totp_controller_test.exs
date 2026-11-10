defmodule PhilomenaWeb.Session.TotpControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures

  alias Philomena.Users
  alias Philomena.Users.User
  alias Philomena.Repo
  alias Phoenix.Flash

  # A TOTP-enabled user with a known set of plaintext backup codes (the
  # fixture's own codes are hashed and discarded).
  defp totp_user_with_backup_codes do
    codes = User.random_backup_codes()
    hashed = Enum.map(codes, &Users.Password.hash_pwd_salt/1)

    user =
      confirmed_user_fixture()
      |> User.create_totp_secret_changeset()
      |> Ecto.Changeset.change(otp_required_for_login: true, otp_backup_codes: hashed)
      |> Repo.update!()

    {user, codes}
  end

  defp valid_totp_code(user), do: :pot.totp(User.totp_secret(user))

  describe "GET /sessions/totp/new" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      conn = get(conn, ~p"/sessions/totp/new")
      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "renders the second-factor form for a logged-in TOTP user", %{conn: conn} do
      user = totp_user_fixture()
      conn = conn |> log_in_user(user) |> get(~p"/sessions/totp/new")
      assert html_response(conn, 200) =~ "Two Factor Authentication"
    end

    test "renders even for a user without TOTP enabled", %{conn: conn} do
      # NOTE: there is no guard against non-TOTP users reaching the form.
      user = confirmed_user_fixture()
      conn = conn |> log_in_user(user) |> get(~p"/sessions/totp/new")
      assert html_response(conn, 200) =~ "Two Factor Authentication"
    end
  end

  describe "POST /sessions/totp" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      conn = post(conn, ~p"/sessions/totp", %{"user" => %{"twofactor_token" => "000000"}})
      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "accepts a valid TOTP code and marks the session TOTP-authenticated", %{conn: conn} do
      user = totp_user_fixture()
      token = valid_totp_code(user)

      conn =
        conn
        |> log_in_user(user)
        |> post(~p"/sessions/totp", %{"user" => %{"twofactor_token" => token}})

      assert redirected_to(conn) == "/"
      assert get_session(conn, :totp_token)
      assert Users.fetch_user_for_worker!(user.id).consumed_timestep == String.to_integer(token)

      # The session now passes :ensure_totp routes.
      conn = get(conn, ~p"/registrations/edit")
      html_response(conn, 200)
    end

    test "writes the TOTP remember cookie with remember_me", %{conn: conn} do
      user = totp_user_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> post(~p"/sessions/totp", %{
          "user" => %{"twofactor_token" => valid_totp_code(user), "remember_me" => "true"}
        })

      assert redirected_to(conn) == "/"
      assert conn.resp_cookies["user_totp_auth"]
    end

    test "accepts a backup code and consumes it", %{conn: conn} do
      {user, [code | _rest]} = totp_user_with_backup_codes()

      conn =
        conn
        |> log_in_user(user)
        |> post(~p"/sessions/totp", %{"user" => %{"twofactor_token" => code}})

      assert redirected_to(conn) == "/"
      assert get_session(conn, :totp_token)
      assert length(Users.fetch_user_for_worker!(user.id).otp_backup_codes) == 9
    end

    test "rejects an invalid token and logs the user out", %{conn: conn} do
      user = totp_user_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> post(~p"/sessions/totp", %{"user" => %{"twofactor_token" => "not a code"}})

      assert redirected_to(conn) == "/"
      assert Flash.get(conn.assigns.flash, :error) =~ "Invalid TOTP token entered"
      refute get_session(conn, :user_token)
      refute get_session(conn, :totp_token)
    end

    test "a numeric token from a user without TOTP enabled is rejected", %{conn: conn} do
      # NOTE: a non-TOTP user (no secret, no backup codes) now takes the
      # invalid-token branch cleanly - totp_valid?/backup_code_valid? guard the
      # nil fields - rather than crashing in the encryptor.
      user = confirmed_user_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> post(~p"/sessions/totp", %{"user" => %{"twofactor_token" => "123456"}})

      assert redirected_to(conn) == "/"
      assert Flash.get(conn.assigns.flash, :error) =~ "Invalid TOTP token entered"
      refute get_session(conn, :user_token)
      refute get_session(conn, :totp_token)
    end

    test "a request without a user param is rejected", %{conn: conn} do
      # NOTE: a missing "user" key now takes the fallback create/2 clause and the
      # invalid-token branch, rather than raising MatchError.
      user = totp_user_fixture()

      conn = conn |> log_in_user(user) |> post(~p"/sessions/totp", %{})

      assert redirected_to(conn) == "/"
      assert Flash.get(conn.assigns.flash, :error) =~ "Invalid TOTP token entered"
      refute get_session(conn, :user_token)
      refute get_session(conn, :totp_token)
    end
  end
end
