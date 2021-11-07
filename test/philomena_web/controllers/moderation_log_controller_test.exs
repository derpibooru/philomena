defmodule PhilomenaWeb.ModerationLogControllerTest do
  use PhilomenaWeb.ConnCase

  import Philomena.ModerationLogsFixtures

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}

  describe "index" do
    test "lists all moderation_logs", %{conn: conn} do
      conn = get(conn, Routes.moderation_log_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Moderation logs"
    end
  end
end
