defmodule PhilomenaWeb.Image.Comment.HideControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.AttributionFixtures
  import Philomena.CommentsFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Comments
  alias Philomena.Repo

  defp hidden_comment(image) do
    comment = comment_fixture(image)

    {:ok, comment} =
      Comments.create_comment_hide(
        actor(moderator_user_fixture()),
        image.id,
        comment.id,
        %{"deletion_reason" => "Spam"}
      )

    comment
  end

  describe "POST /images/:image_id/comments/:comment_id/hide" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image)

      conn =
        post(conn, ~p"/images/#{image}/comments/#{comment}/hide", %{
          "comment" => %{"deletion_reason" => "Spam"}
        })

      assert redirected_to(conn) == ~p"/sessions/new"
      refute Repo.reload!(comment).hidden_from_users
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()
      comment = comment_fixture(image)

      conn =
        post(conn, ~p"/images/#{image}/comments/#{comment}/hide", %{
          "comment" => %{"deletion_reason" => "Spam"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.reload!(comment).hidden_from_users
    end

    test "as a moderator hides the comment and redirects to its anchor", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()
      comment = comment_fixture(image)

      conn =
        post(conn, ~p"/images/#{image}/comments/#{comment}/hide", %{
          "comment" => %{"deletion_reason" => "Rule violation"}
        })

      assert redirected_to(conn) == ~p"/images/#{image}" <> "#comment_#{comment.id}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Comment successfully deleted!"

      comment = Repo.reload!(comment)
      assert comment.hidden_from_users
      assert comment.deletion_reason == "Rule violation"
    end

    # Failure path: hide_changeset validates the deletion reason as required,
    # so a blank reason takes the error branch.
    test "with a blank deletion reason redirects with the error flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()
      comment = comment_fixture(image)

      conn =
        post(conn, ~p"/images/#{image}/comments/#{comment}/hide", %{
          "comment" => %{"deletion_reason" => ""}
        })

      assert redirected_to(conn) == ~p"/images/#{image}" <> "#comment_#{comment.id}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Unable to delete comment!"
      refute Repo.reload!(comment).hidden_from_users
    end

    test "for an unknown comment_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn =
        post(conn, ~p"/images/#{image}/comments/999999999/hide", %{
          "comment" => %{"deletion_reason" => "Spam"}
        })

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    # NOTE: a non-integer comment_id short-circuits to NotFoundPlug via the
    # central IntegerId guard before authorization runs.
    test "for a non-integer comment_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn =
        post(conn, ~p"/images/#{image}/comments/not-a-number/hide", %{
          "comment" => %{"deletion_reason" => "Spam"}
        })

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    test "does not hide a comment through a different route image", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()
      other_image = image_fixture()
      comment = comment_fixture(image)

      conn =
        post(conn, ~p"/images/#{other_image}/comments/#{comment}/hide", %{
          "comment" => %{"deletion_reason" => "Spam"}
        })

      assert redirected_to(conn) == "/"
      refute Repo.reload!(comment).hidden_from_users
    end
  end

  describe "DELETE /images/:image_id/comments/:comment_id/hide" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture()
      comment = hidden_comment(image)

      conn = delete(conn, ~p"/images/#{image}/comments/#{comment}/hide")

      assert redirected_to(conn) == ~p"/sessions/new"
      assert Repo.reload!(comment).hidden_from_users
    end

    test "rejects a regular user", %{conn: conn} do
      image = image_fixture()
      comment = hidden_comment(image)
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = delete(conn, ~p"/images/#{image}/comments/#{comment}/hide")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(comment).hidden_from_users
    end

    test "as a moderator restores the comment", %{conn: conn} do
      image = image_fixture()
      comment = hidden_comment(image)
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = delete(conn, ~p"/images/#{image}/comments/#{comment}/hide")

      assert redirected_to(conn) == ~p"/images/#{image}" <> "#comment_#{comment.id}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Comment successfully restored!"

      comment = Repo.reload!(comment)
      refute comment.hidden_from_users
      assert comment.deletion_reason == ""
    end

    # Unhiding an already-visible comment still succeeds (the changeset sets
    # the column unconditionally).
    test "restoring a non-hidden comment still succeeds", %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image)
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = delete(conn, ~p"/images/#{image}/comments/#{comment}/hide")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Comment successfully restored!"
      refute Repo.reload!(comment).hidden_from_users
    end

    test "does not restore a comment through a different route image", %{conn: conn} do
      image = image_fixture()
      other_image = image_fixture()
      comment = hidden_comment(image)
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = delete(conn, ~p"/images/#{other_image}/comments/#{comment}/hide")

      assert redirected_to(conn) == "/"
      assert Repo.reload!(comment).hidden_from_users
    end
  end
end
