defmodule PhilomenaWeb.SearchViewTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures
  alias PhilomenaWeb.SearchView

  describe "hides_images?/1" do
    test "is unavailable to anonymous and regular viewers", %{conn: conn} do
      refute SearchView.hides_images?(viewer_conn(conn, nil))
      refute SearchView.hides_images?(viewer_conn(conn, confirmed_user_fixture()))
    end

    test "is available to moderators and admins", %{conn: conn} do
      assert SearchView.hides_images?(viewer_conn(conn, moderator_user_fixture()))
      assert SearchView.hides_images?(viewer_conn(conn, admin_user_fixture()))
    end
  end
end
