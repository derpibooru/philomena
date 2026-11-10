defmodule PhilomenaWeb.ConfirmationControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  alias Philomena.Users
  alias Philomena.Repo
  alias Phoenix.Flash
  import Philomena.UsersFixtures

  setup do
    %{user: user_fixture()}
  end

  describe "GET /confirmations/new" do
    test "renders the confirmation page", %{conn: conn} do
      conn = get(conn, ~p"/confirmations/new")
      response = html_response(conn, 200)
      assert response =~ "<h1>Resend confirmation instructions</h1>"
    end
  end

  describe "POST /confirmations" do
    @tag :capture_log
    test "sends a new confirmation token", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/confirmations", %{
          "user" => %{"email" => user.email}
        })

      assert redirected_to(conn) == "/"
      assert Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"
      assert Repo.get_by!(Users.UserToken, user_id: user.id).context == "confirm"
    end

    test "does not send confirmation token if account is confirmed", %{conn: conn, user: user} do
      Repo.update!(Users.User.confirm_changeset(user))

      conn =
        post(conn, ~p"/confirmations", %{
          "user" => %{"email" => user.email}
        })

      assert redirected_to(conn) == "/"
      assert Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"
      refute Repo.get_by(Users.UserToken, user_id: user.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/confirmations", %{
          "user" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == "/"
      assert Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"
      assert Repo.all(Users.UserToken) == []
    end
  end

  describe "GET /confirmations/:id" do
    test "renders the confirmation form without confirming the account", %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Users.deliver_user_confirmation_instructions(user, url)
        end)

      conn = get(conn, ~p"/confirmations/#{token}")
      response = html_response(conn, 200)

      assert response =~ "<h1>Confirm account</h1>"
      assert response =~ ~s(action="/confirmations/#{token}")
      refute Users.fetch_user_for_worker!(user.id).confirmed_at
      assert Repo.get_by!(Users.UserToken, user_id: user.id).context == "confirm"
    end
  end

  describe "PUT /confirmations/:id" do
    test "confirms the given token once", %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Users.deliver_user_confirmation_instructions(user, url)
        end)

      conn = put(conn, ~p"/confirmations/#{token}")
      assert redirected_to(conn) == "/"
      assert Flash.get(conn.assigns.flash, :info) =~ "Account confirmed successfully"
      assert Users.fetch_user_for_worker!(user.id).confirmed_at
      refute get_session(conn, :user_token)
      assert Repo.all(Users.UserToken) == []

      conn = put(conn, ~p"/confirmations/#{token}")
      assert redirected_to(conn) == "/"

      assert Flash.get(conn.assigns.flash, :error) =~
               "Confirmation link is invalid or it has expired"
    end

    test "does not confirm email with invalid token", %{conn: conn, user: user} do
      conn = put(conn, ~p"/confirmations/oops")
      assert redirected_to(conn) == "/"

      assert Flash.get(conn.assigns.flash, :error) =~
               "Confirmation link is invalid or it has expired"

      refute Users.fetch_user_for_worker!(user.id).confirmed_at
    end
  end

  describe "when already logged in" do
    test "GET /confirmations/new redirects to the homepage", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/confirmations/new")
      assert redirected_to(conn) == "/"
    end

    # EnsureUserEnabledPlug exempts a merely-unconfirmed session on the
    # confirmation path only, and the router moved /confirmations/:id
    # out of redirect_if_user_is_authenticated, so a logged-in unconfirmed user
    # can follow their own link and confirm the account while staying logged in.
    test "GET /confirmations/:id renders the form for an unconfirmed logged-in user",
         %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Users.deliver_user_confirmation_instructions(user, url)
        end)

      conn = conn |> log_in_user(user) |> get(~p"/confirmations/#{token}")

      assert html_response(conn, 200) =~ "<h1>Confirm account</h1>"
      refute Users.fetch_user_for_worker!(user.id).confirmed_at
      assert get_session(conn, :user_token)
    end

    test "PUT /confirmations/:id confirms an unconfirmed logged-in user and keeps them logged in",
         %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Users.deliver_user_confirmation_instructions(user, url)
        end)

      conn = conn |> log_in_user(user) |> put(~p"/confirmations/#{token}")

      assert redirected_to(conn) == "/"
      assert Flash.get(conn.assigns.flash, :info) =~ "Account confirmed successfully."
      assert get_session(conn, :user_token)
      assert Users.fetch_user_for_worker!(user.id).confirmed_at
    end

    # A deactivated (deleted_at set) account is locked out everywhere,
    # including the confirmation-show path, so it is still logged out and left
    # unconfirmed.
    test "GET /confirmations/:id logs a deactivated user out without confirming",
         %{conn: conn} do
      user = deactivated_user_fixture()

      token =
        extract_user_token(fn url ->
          Users.deliver_user_confirmation_instructions(user, url)
        end)

      conn = conn |> log_in_user(user) |> get(~p"/confirmations/#{token}")

      assert redirected_to(conn) == "/"
      assert Flash.get(conn.assigns.flash, :error) =~ "Your account is not currently active."
      refute get_session(conn, :user_token)
      refute Users.fetch_user_for_worker!(user.id).confirmed_at
    end

    test "PUT /confirmations/:id silently redirects confirmed users for invalid tokens",
         %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = put(conn, ~p"/confirmations/oops")

      assert redirected_to(conn) == "/"
      refute Flash.get(conn.assigns.flash, :error)
      assert get_session(conn, :user_token)
    end

    # NOTE: the EnsureUserEnabledPlug exemption is show-only, so an unconfirmed
    # logged-in user hitting the resend-instructions form is still logged out.
    test "GET /confirmations/new logs an unconfirmed user out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> get(~p"/confirmations/new")

      assert redirected_to(conn) == "/"
      assert Flash.get(conn.assigns.flash, :error) =~ "Your account is not currently active."
      refute get_session(conn, :user_token)
    end
  end
end
