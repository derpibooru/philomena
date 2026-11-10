defmodule PhilomenaWeb.ReportControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ImagesFixtures
  import Philomena.ReportsFixtures
  import Philomena.UsersFixtures

  test "anonymous GET /reports redirects to the login page", %{conn: conn} do
    conn = get(conn, ~p"/reports")

    assert redirected_to(conn) == ~p"/sessions/new"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "You must log in to access this page."
  end

  test "GET /reports lists the user's own reports but not others'", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    image = image_fixture()

    _own = report_fixture(user, %{"reason" => "My own report reason"}, image_id: image.id)

    _other =
      report_fixture(confirmed_user_fixture(), %{"reason" => "Somebody else's report reason"},
        image_id: image.id
      )

    response = html_response(get(conn, ~p"/reports"), 200)

    assert response =~ "My Reports - Derpibooru"
    assert response =~ "My own report reason"
    refute response =~ "Somebody else&#39;s report reason"
  end

  test "GET /reports with no reports renders the empty index", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    response = html_response(get(conn, ~p"/reports"), 200)

    assert response =~ "My Reports - Derpibooru"
  end
end
