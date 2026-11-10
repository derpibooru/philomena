defmodule PhilomenaWeb.DuplicateReportViewTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias PhilomenaWeb.DuplicateReportView

  describe "comparison_url/2" do
    test "uses the public thumbnail path for viewers without hidden-image access", %{
      conn: conn
    } do
      image = image_fixture(hidden_from_users: true, hidden_image_key: "comparison-secret")

      url = DuplicateReportView.comparison_url(viewer_conn(conn, nil), image)

      assert url =~ "/#{image.id}/full.png"
      refute url =~ image.hidden_image_key
    end

    test "uses the hidden thumbnail path for moderators", %{conn: conn} do
      image = image_fixture(hidden_from_users: true, hidden_image_key: "comparison-secret")
      moderator_conn = viewer_conn(conn, moderator_user_fixture())

      url = DuplicateReportView.comparison_url(moderator_conn, image)

      assert url =~ "#{image.id}-#{image.hidden_image_key}/full.png"
    end
  end
end
