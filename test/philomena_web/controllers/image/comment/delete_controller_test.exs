defmodule PhilomenaWeb.Image.Comment.DeleteControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.AttributionFixtures
  import Philomena.CommentsFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Comments
  alias Philomena.Repo

  defp hidden_comment(image, user \\ nil, attrs \\ %{}) do
    comment = comment_fixture(image, user, attrs)

    {:ok, comment} =
      Comments.create_comment_hide(
        actor(moderator_user_fixture()),
        image.id,
        comment.id,
        %{"deletion_reason" => "Spam"}
      )

    comment
  end

  describe "POST /images/:image_id/comments/:comment_id/delete" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture()
      comment = hidden_comment(image, nil, %{"body" => "keep me"})

      conn = post(conn, ~p"/images/#{image}/comments/#{comment}/delete")

      assert redirected_to(conn) == ~p"/sessions/new"
      refute Repo.reload!(comment).destroyed_content
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()
      comment = hidden_comment(image, nil, %{"body" => "keep me"})

      conn = post(conn, ~p"/images/#{image}/comments/#{comment}/delete")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.reload!(comment).destroyed_content
    end

    test "as a moderator destroys the comment content", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()
      comment = hidden_comment(image, nil, %{"body" => "obliterate me"})

      conn = post(conn, ~p"/images/#{image}/comments/#{comment}/delete")

      assert redirected_to(conn) == ~p"/images/#{image}" <> "#comment_#{comment.id}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Comment successfully destroyed!"

      comment = Repo.reload!(comment)
      assert comment.destroyed_content
      assert comment.body == ""
    end

    test "as an admin destroys the comment content", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      image = image_fixture()
      comment = hidden_comment(image)

      conn = post(conn, ~p"/images/#{image}/comments/#{comment}/delete")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Comment successfully destroyed!"
      assert Repo.reload!(comment).destroyed_content
    end

    test "fails if the comment is visible", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()
      comment = comment_fixture(image, nil, %{"body" => "keep me"})

      conn = post(conn, ~p"/images/#{image}/comments/#{comment}/delete")

      assert redirected_to(conn) == ~p"/images/#{image}" <> "#comment_#{comment.id}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Unable to destroy comment!"

      comment = Repo.reload!(comment)
      refute comment.destroyed_content
      refute comment.body == ""
    end

    test "for an unknown comment_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/comments/999999999/delete")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    # NOTE: a non-integer comment_id short-circuits to NotFoundPlug via the
    # central IntegerId guard before authorization runs.
    test "for a non-integer comment_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/comments/not-a-number/delete")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    test "does not destroy a comment through a different route image", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()
      other_image = image_fixture()
      comment = hidden_comment(image, nil, %{"body" => "keep me"})

      conn = post(conn, ~p"/images/#{other_image}/comments/#{comment}/delete")

      assert redirected_to(conn) == "/"
      refute Repo.reload!(comment).destroyed_content
    end
  end
end
