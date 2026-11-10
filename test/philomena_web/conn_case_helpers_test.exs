defmodule PhilomenaWeb.ConnCaseHelpersTest do
  @moduledoc """
  Smoke tests for the role helpers in `PhilomenaWeb.ConnCase` (phase 0 of
  the characterization-test plan). These pin that each helper produces a
  session the relevant pipeline plugs actually accept, using Postgres-only
  routes.
  """

  use PhilomenaWeb.ConnCase, async: true

  alias Philomena.UsersFixtures

  # GET /forums crashes on an empty forum table, so
  # the tests that browse it need at least one forum row.
  defp create_forum(_context) do
    %{forum: Philomena.ForumsFixtures.forum_fixture()}
  end

  describe "register_and_log_in_moderator/1" do
    setup [:register_and_log_in_moderator, :create_forum]

    test "authenticates a user with the moderator role", %{conn: conn, user: user} do
      assert user.role == "moderator"

      conn = get(conn, ~p"/forums")
      assert html_response(conn, 200)
      assert conn.assigns.current_user.id == user.id
    end
  end

  describe "register_and_log_in_admin/1" do
    setup [:register_and_log_in_admin, :create_forum]

    test "authenticates a user with the admin role", %{conn: conn, user: user} do
      assert user.role == "admin"

      conn = get(conn, ~p"/forums")
      assert html_response(conn, 200)
      assert conn.assigns.current_user.id == user.id
    end
  end

  describe "register_and_log_in_banned_user/1" do
    setup [:register_and_log_in_banned_user, :create_forum]

    test "requests carry the ban in current_ban", %{conn: conn, user: user} do
      conn = get(conn, ~p"/forums")

      # NOTE: a ban does not block read access; it surfaces as the
      # :current_ban assign, which write actions check.
      assert html_response(conn, 200)
      assert conn.assigns.current_user.id == user.id
      assert conn.assigns.current_ban.reason == "Banned in test"
    end
  end

  describe "register_and_log_in_role_moderator/2" do
    setup %{conn: conn} do
      register_and_log_in_role_moderator(%{conn: conn}, "Badge")
    end

    test "grants a moderator the resource_type admin role_map entry", %{conn: conn, user: user} do
      assert user.role == "moderator"

      # The "Badge" role_map grant lets an otherwise-plain moderator reach the
      # admin badge index, which a plain moderator is denied.
      conn = get(conn, ~p"/admin/badges")
      assert html_response(conn, 200) =~ "Badges"
      assert conn.assigns.current_user.id == user.id
    end
  end

  describe "register_and_log_in_totp_user/1" do
    setup :register_and_log_in_totp_user

    test "passes the ensure_totp pipeline", %{conn: conn, user: user} do
      assert user.otp_required_for_login

      conn = get(conn, ~p"/registrations/edit")
      assert html_response(conn, 200)
    end
  end

  describe "log_in_user/2 with a TOTP-enabled user" do
    test "is redirected to the TOTP prompt by ensure_totp", %{conn: conn} do
      user = UsersFixtures.totp_user_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> get(~p"/registrations/edit")

      assert redirected_to(conn) == ~p"/sessions/totp/new"
    end
  end

  describe "create_api_user/1" do
    setup :create_api_user

    test "api_key authenticates /api/v1 requests", %{conn: conn, api_key: api_key} do
      conn = get(conn, ~p"/api/v1/json/filters/user?key=#{api_key}")

      assert %{"filters" => []} = json_response(conn, 200)
    end
  end
end
