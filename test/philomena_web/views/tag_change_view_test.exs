defmodule PhilomenaWeb.TagChangeViewTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures
  alias PhilomenaWeb.TagChangeView

  describe "reverts_tag_changes?/1" do
    test "is unavailable to anonymous and regular viewers", %{conn: conn} do
      refute TagChangeView.reverts_tag_changes?(viewer_conn(conn, nil))
      refute TagChangeView.reverts_tag_changes?(viewer_conn(conn, confirmed_user_fixture()))
    end

    test "is available to moderators and admins", %{conn: conn} do
      assert TagChangeView.reverts_tag_changes?(viewer_conn(conn, moderator_user_fixture()))
      assert TagChangeView.reverts_tag_changes?(viewer_conn(conn, admin_user_fixture()))
    end
  end
end
