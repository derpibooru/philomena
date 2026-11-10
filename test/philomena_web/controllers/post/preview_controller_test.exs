defmodule PhilomenaWeb.Post.PreviewControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  test "POST renders the markdown preview without a layout for anonymous users",
       %{conn: conn} do
    conn = post(conn, ~p"/posts/preview", %{"body" => "Some *emphasized* text"})

    response = html_response(conn, 200)

    assert response =~ "<em>emphasized</em>"
    refute response =~ "Derpibooru"
  end

  test "POST renders the preview attributed to the logged-in user", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

    conn = post(conn, ~p"/posts/preview", %{"body" => "Preview body text"})

    response = html_response(conn, 200)

    assert response =~ "Preview body text"
    assert response =~ user.name
  end

  test "POST with no body renders an empty preview", %{conn: conn} do
    conn = post(conn, ~p"/posts/preview", %{})

    assert html_response(conn, 200)
  end
end
