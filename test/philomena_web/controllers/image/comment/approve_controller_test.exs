defmodule PhilomenaWeb.Image.Comment.ApproveControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.CommentsFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures
  import Philomena.RulesFixtures

  alias Philomena.Repo

  # A comment whose body contains an external link, posted by an untrusted
  # (freshly-registered) user, is withheld from approval.
  defp unapproved_comment(image) do
    _rule = rule_fixture(name: "Approval")

    comment =
      comment_fixture(image, confirmed_user_fixture(), %{
        "body" => "buy now at https://spam.example/"
      })

    refute Repo.reload!(comment).approved
    comment
  end

  describe "POST /images/:image_id/comments/:comment_id/approve" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture()
      comment = unapproved_comment(image)

      conn = post(conn, ~p"/images/#{image}/comments/#{comment}/approve")

      assert redirected_to(conn) == ~p"/sessions/new"
      refute Repo.reload!(comment).approved
    end

    test "rejects a regular user", %{conn: conn} do
      image = image_fixture()
      comment = unapproved_comment(image)
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = post(conn, ~p"/images/#{image}/comments/#{comment}/approve")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.reload!(comment).approved
    end

    test "as a moderator approves the comment", %{conn: conn} do
      image = image_fixture()
      comment = unapproved_comment(image)
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/images/#{image}/comments/#{comment}/approve")

      assert redirected_to(conn) == ~p"/images/#{image}" <> "#comment_#{comment.id}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Comment has been approved."
      assert Repo.reload!(comment).approved
    end

    test "as an admin approves the comment", %{conn: conn} do
      image = image_fixture()
      comment = unapproved_comment(image)
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = post(conn, ~p"/images/#{image}/comments/#{comment}/approve")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Comment has been approved."
      assert Repo.reload!(comment).approved
    end

    # Approving an already-approved comment is idempotent (no verify plug).
    test "approving an already-approved comment still succeeds", %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image)
      assert Repo.reload!(comment).approved
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/images/#{image}/comments/#{comment}/approve")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Comment has already been approved."
      assert Repo.reload!(comment).approved
    end

    test "for an unknown comment_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/comments/999999999/approve")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    # NOTE: a non-integer comment_id short-circuits to NotFoundPlug via the
    # central IntegerId guard before authorization runs.
    test "for a non-integer comment_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/comments/not-a-number/approve")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    test "does not approve a comment through a different route image", %{conn: conn} do
      image = image_fixture()
      other_image = image_fixture()
      comment = unapproved_comment(image)
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/images/#{other_image}/comments/#{comment}/approve")

      assert redirected_to(conn) == "/"
      refute Repo.reload!(comment).approved
    end
  end
end
