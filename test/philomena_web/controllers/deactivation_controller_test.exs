defmodule PhilomenaWeb.DeactivationControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  alias Philomena.Users

  setup :register_and_log_in_user

  describe "GET /deactivations" do
    test "renders the deactivate account page", %{conn: conn} do
      conn = get(conn, ~p"/deactivations")
      response = html_response(conn, 200)
      assert response =~ "<h1>Deactivate Account</h1>"
    end
  end

  describe "DELETE /deactivations" do
    test "causes the user to be deactivated", %{conn: conn, user: user} do
      conn = delete(conn, ~p"/deactivations")
      assert redirected_to(conn) == ~p"/"
      conn = get(conn, ~p"/registrations/edit")
      assert redirected_to(conn) == ~p"/sessions/new"

      user = Users.fetch_user_for_worker!(user.id)
      assert user.deleted_by_user_id == user.id
    end

    test "a double submit logs out instead of failing", %{conn: conn, user: user} do
      # Both submits pass the pipeline before the first deactivation commits.
      conn =
        conn
        |> bypass_through(PhilomenaWeb.Router, [:browser])
        |> delete(~p"/deactivations")

      {:ok, _user} = Users.delete_deactivation(conn.assigns.actor, &"/reactivations/#{&1}")
      conn = PhilomenaWeb.DeactivationController.call(conn, :delete)

      assert redirected_to(conn) == ~p"/"
      assert Users.fetch_user_for_worker!(user.id).deleted_by_user_id == user.id
    end
  end

  describe "DELETE /deactivations when banned" do
    setup :register_and_log_in_banned_user

    test "refuses with the ban response and keeps the account active", %{conn: conn, user: user} do
      conn = delete(conn, ~p"/deactivations")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You are currently banned."
      refute Users.fetch_user_for_worker!(user.id).deleted_at
    end
  end

  describe "when not logged in" do
    test "GET /deactivations redirects to the login page" do
      conn = build_conn() |> get(~p"/deactivations")
      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "DELETE /deactivations redirects to the login page" do
      conn = build_conn() |> delete(~p"/deactivations")
      assert redirected_to(conn) == ~p"/sessions/new"
    end
  end
end
