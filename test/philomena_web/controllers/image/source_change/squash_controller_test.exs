defmodule PhilomenaWeb.Image.SourceChange.SquashControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  import Philomena.ImagesFixtures

  for role <- [:user, :moderator, :admin, :banned_user, :banned_admin] do
    describe "#{role}" do
      setup :"register_and_log_in_#{role}"

      test "squash authorization", %{conn: conn} do
        image = image_fixture()
        conn = post(conn, ~p"/images/#{image}/source_changes/squash")

        expected =
          if unquote(role) in [:moderator, :admin],
            do: ~p"/images/#{image}/source_changes",
            else: "/"

        assert redirected_to(conn) == expected
      end
    end
  end

  test "anonymous cannot squash", %{conn: conn} do
    assert conn |> post(~p"/images/1/source_changes/squash") |> redirected_to() == "/"
  end

  describe "invalid target" do
    setup :register_and_log_in_moderator

    test "malformed image id", %{conn: conn} do
      assert conn |> post(~p"/images/invalid/source_changes/squash") |> redirected_to() == "/"
    end
  end
end
