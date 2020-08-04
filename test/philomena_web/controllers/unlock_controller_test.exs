defmodule PhilomenaWeb.UnlockControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  alias Philomena.Users
  alias Philomena.Repo
  import Philomena.UsersFixtures

  setup do
    %{user: locked_user_fixture()}
  end

  describe "GET /unlocks/new" do
    test "renders the unlock page", %{conn: conn} do
      conn = get(conn, Routes.unlock_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Resend unlock instructions</h1>"
    end
  end

  describe "POST /unlocks" do
    @tag :capture_log
    test "sends a new unlock token", %{conn: conn, user: user} do
      conn =
        post(conn, Routes.unlock_path(conn, :create), %{
          "user" => %{"email" => user.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.get_by!(Users.UserToken, user_id: user.id).context == "unlock"
    end

    test "does not send unlock token if account is not locked", %{conn: conn, user: user} do
      Repo.update!(Users.User.unlock_changeset(user))

      conn =
        post(conn, Routes.unlock_path(conn, :create), %{
          "user" => %{"email" => user.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      refute Repo.get_by(Users.UserToken, user_id: user.id)
    end

    test "does not send unlock token if email is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.unlock_path(conn, :create), %{
          "user" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.all(Users.UserToken) == []
    end
  end

  describe "GET /unlocks/:id" do
    test "confirms the given token once", %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Users.deliver_user_unlock_instructions(user, url)
        end)

      conn = get(conn, Routes.unlock_path(conn, :show, token))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "Account unlocked successfully"
      refute Users.get_user!(user.id).locked_at
      refute get_session(conn, :user_token)
      assert Repo.all(Users.UserToken) == []

      conn = get(conn, Routes.unlock_path(conn, :show, token))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Unlock link is invalid or it has expired"
    end

    test "does not unlock with invalid token", %{conn: conn, user: user} do
      conn = get(conn, Routes.unlock_path(conn, :show, "oops"))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Unlock link is invalid or it has expired"
      assert Users.get_user!(user.id).locked_at
    end
  end
end
