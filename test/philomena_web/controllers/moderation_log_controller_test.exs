defmodule PhilomenaWeb.ModerationLogControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  alias Philomena.ModerationLogs

  describe "GET /moderation_logs" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      conn = get(conn, ~p"/moderation_logs")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "redirects a regular user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/moderation_logs")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "lists moderation log entries for a moderator", %{conn: conn} do
      %{conn: conn, user: mod} = register_and_log_in_moderator(%{conn: conn})

      {:ok, _log} =
        ModerationLogs.create_moderation_log(
          mod,
          "test_event",
          "/images/1",
          "Did a moderator thing"
        )

      response = html_response(get(conn, ~p"/moderation_logs"), 200)

      assert response =~ "Listing Moderation Logs"
      assert response =~ "Did a moderator thing"
      assert response =~ mod.name
    end

    test "renders an empty listing when there are no logs", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      response = html_response(get(conn, ~p"/moderation_logs"), 200)

      assert response =~ "Listing Moderation Logs"
    end
  end
end
