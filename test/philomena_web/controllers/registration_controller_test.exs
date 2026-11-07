defmodule PhilomenaWeb.RegistrationControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.BansFixtures
  import Philomena.UsersFixtures

  alias Philomena.Repo

  @banned_fingerprint "d015c342859dde3"

  describe "GET /registrations/new" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, ~p"/registrations/new")
      html_response(conn, 200)
    end

    test "renders on a first visit, before the fingerprint cookie is set", %{conn: conn} do
      conn = get(without_fingerprint(conn), ~p"/registrations/new")
      html_response(conn, 200)
    end

    test "redirects if already logged in", %{conn: conn} do
      conn =
        conn |> log_in_user(confirmed_user_fixture()) |> get(~p"/registrations/new")

      assert redirected_to(conn) == "/"
    end

    test "rejects a banned actor", %{conn: conn} do
      fingerprint_ban_fixture(%{"fingerprint" => @banned_fingerprint})

      conn =
        conn
        |> put_req_cookie("_ses", @banned_fingerprint)
        |> get(~p"/registrations/new")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You are currently banned."
    end
  end

  describe "POST /registrations" do
    @tag :capture_log
    test "creates account but doesn't log the user in", %{conn: conn} do
      email = unique_user_email()

      conn =
        post(conn, ~p"/registrations", %{
          "user" => %{"name" => email, "email" => email, "password" => valid_user_password()}
        })

      assert redirected_to(conn) =~ "/"

      conn = get(conn, "/sessions/new")
      html_response(conn, 200)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "email for confirmation instructions"
    end

    test "render errors for invalid data", %{conn: conn} do
      conn =
        post(conn, ~p"/registrations", %{
          "user" => %{"email" => "with spaces", "password" => "too short"}
        })

      response = html_response(conn, 200)
      assert response =~ "must be valid (e.g., user@example.com)"
      assert response =~ "should be at least 12 character"
    end

    test "refuses a submission without a fingerprint", %{conn: conn} do
      email = unique_user_email()

      conn =
        post(without_fingerprint(conn), ~p"/registrations", %{
          "user" => %{"email" => email, "password" => valid_user_password()}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Philomena.Users.get_user_by_email(email)
    end

    test "rejects a banned actor", %{conn: conn} do
      fingerprint_ban_fixture(%{"fingerprint" => @banned_fingerprint})
      email = unique_user_email()

      conn =
        conn
        |> put_req_cookie("_ses", @banned_fingerprint)
        |> post(~p"/registrations", %{
          "user" => %{
            "name" => email,
            "email" => email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You are currently banned."
    end
  end

  describe "GET /registration/edit" do
    setup :register_and_log_in_user

    test "renders settings page", %{conn: conn} do
      conn = get(conn, ~p"/registrations/edit")
      response = html_response(conn, 200)
      assert response =~ "Settings"
    end

    test "renders the deactivation section of the settings page", %{conn: conn} do
      conn = get(conn, ~p"/registrations/edit")
      response = html_response(conn, 200)
      assert response =~ "<h3>Deactivate Account</h3>"
    end

    test "renders the username-change link only while the account is eligible", %{
      conn: conn,
      user: user
    } do
      response = html_response(get(conn, ~p"/registrations/edit"), 200)
      assert response =~ ~p"/registrations/name/edit"

      user
      |> Ecto.Changeset.change(last_renamed_at: DateTime.utc_now(:second))
      |> Repo.update!()

      response = html_response(get(conn, ~p"/registrations/edit"), 200)
      refute response =~ ~p"/registrations/name/edit"
    end

    test "redirects if user is not logged in" do
      conn = build_conn()
      conn = get(conn, ~p"/registrations/edit")
      assert redirected_to(conn) == ~p"/sessions/new"
    end
  end

  describe "PATCH/PUT /registrations (no longer routed)" do
    setup :register_and_log_in_user

    # NOTE: the router now routes only :edit for the registration singleton, so
    # PATCH/PUT /registrations is unrouted and answers 404 - account settings
    # save through the nested Registration.* singletons and /settings instead.
    test "PATCH answers 404 for a logged-in user", %{conn: conn} do
      conn = patch(conn, "/registrations", %{"user" => %{}})

      assert conn.status == 404
    end

    test "PUT answers 404 for a logged-in user", %{conn: conn} do
      conn = put(conn, "/registrations", %{"user" => %{}})

      assert conn.status == 404
    end

    # NOTE: with the route gone the pipeline never runs, so an anonymous user
    # gets the same 404 rather than the login redirect.
    test "PATCH answers 404 for an anonymous user" do
      conn = build_conn()
      conn = patch(conn, "/registrations", %{"user" => %{}})

      assert conn.status == 404
    end
  end
end
