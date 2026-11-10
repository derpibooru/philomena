defmodule PhilomenaWeb.Filter.SpoilerTypeControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  alias Philomena.Users.Settings
  alias Philomena.Repo

  test "anonymous PATCH redirects to the login page", %{conn: conn} do
    conn = patch(conn, ~p"/filters/spoiler_type")
    PhilomenaWeb.SingletonToggleTests.assert_login_redirect(conn)
  end

  test "PATCH updates the spoiler type and redirects to the referrer default",
       %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    assert user.settings.spoiler_type == "static"

    conn = patch(conn, ~p"/filters/spoiler_type", %{"settings" => %{"spoiler_type" => "click"}})

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Changed spoiler type to click"
    assert Repo.get!(Settings, user.id).spoiler_type == "click"
  end

  test "PATCH redirects to the Referer header when present", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn =
      conn
      |> put_req_header("referer", "http://www.example.com/filters")
      |> patch(~p"/filters/spoiler_type", %{"settings" => %{"spoiler_type" => "hover"}})

    assert redirected_to(conn) == "http://www.example.com/filters"
  end

  test "PUT is routed to the same action", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

    conn = put(conn, ~p"/filters/spoiler_type", %{"settings" => %{"spoiler_type" => "off"}})

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Changed spoiler type to off"
    assert Repo.get!(Settings, user.id).spoiler_type == "off"
  end

  test "banned users can change their spoiler type", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_banned_user(%{conn: conn})

    conn =
      patch(conn, ~p"/filters/spoiler_type", %{
        "settings" => %{"spoiler_type" => "click"}
      })

    assert redirected_to(conn) == "/"
    assert Repo.get!(Settings, user.id).spoiler_type == "click"
  end

  test "PATCH with an invalid spoiler type redirects with the failure flash", %{conn: conn} do
    # NOTE: an invalid spoiler_type now redirects to the referrer with the
    # failure flash rather than raising MatchError.
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

    conn = patch(conn, ~p"/filters/spoiler_type", %{"settings" => %{"spoiler_type" => "bogus"}})

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Couldn't change spoiler type!"
    assert Repo.get!(Settings, user.id).spoiler_type == "static"
  end

  test "PATCH without settings params redirects with the failure flash", %{conn: conn} do
    # NOTE: a request without the settings param takes the fallback update/2 clause
    # and redirects with the failure flash rather than raising ActionClauseError.
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn = patch(conn, ~p"/filters/spoiler_type")

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Couldn't change spoiler type!"
  end
end
