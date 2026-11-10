defmodule PhilomenaWeb.Image.Comment.HistoryControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.AttributionFixtures, only: [actor: 1]
  import Philomena.CommentsFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Comments

  describe "GET /images/:image_id/comments/:comment_id/history" do
    test "renders the edit history for anonymous users", %{conn: conn} do
      image = image_fixture()
      author = confirmed_user_fixture()
      comment = comment_fixture(image, author, %{"body" => "Original comment body"})

      {:ok, _} =
        Comments.update_comment(actor(author), image.id, comment.id, %{
          "body" => "Original comment body plus an edit",
          "edit_reason" => "typo fix"
        })

      conn = get(conn, ~p"/images/#{image}/comments/#{comment}/history")
      response = html_response(conn, 200)

      assert response =~ "Comment History for comment #{comment.id} on image #{image.id}"
      assert response =~ "Viewing last 25 versions of comment by"
      assert response =~ author.name
      # The version body renders as a line-by-line unified diff table over the
      # raw markdown source. An in-place edit of a line produces a deleted row
      # for the old text and an inserted row for the new, with word-level
      # highlights marking the change.
      assert response =~ ~s(<table class="diff">)
      assert response =~ ~s(<tr class="diff__row diff__row--del">)
      assert response =~ ~s(<tr class="diff__row diff__row--ins">)
      assert response =~ "Original comment body"
      assert response =~ ~s(<ins class="diff__hl"> plus an edit</ins>)
    end

    test "renders an empty history for a never-edited comment", %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image)

      conn = get(conn, ~p"/images/#{image}/comments/#{comment}/history")
      response = html_response(conn, 200)

      assert response =~ "Comment History for comment #{comment.id} on image #{image.id}"
    end

    test "redirects to / for an unknown comment", %{conn: conn} do
      image = image_fixture()

      conn = get(conn, ~p"/images/#{image}/comments/999999999/history")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "redirects to / for an unknown image", %{conn: conn} do
      conn = get(conn, ~p"/images/999999999/comments/1/history")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "redirects to / when the route image does not own the comment", %{conn: conn} do
      image = image_fixture()
      other_image = image_fixture()
      comment = comment_fixture(image)

      conn = get(conn, ~p"/images/#{other_image}/comments/#{comment}/history")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end
  end
end
