defmodule PhilomenaWeb.Image.ApproveControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ImagesFixtures

  alias Philomena.Repo

  describe "POST /images/:image_id/approve" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture(approved: false)

      conn = post(conn, ~p"/images/#{image}/approve")

      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
      refute Repo.reload!(image).approved
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture(approved: false)

      conn = post(conn, ~p"/images/#{image}/approve")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.reload!(image).approved
    end

    test "as a moderator approves the image and redirects to the approval queue", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture(approved: false)

      conn = post(conn, ~p"/images/#{image}/approve")

      assert redirected_to(conn) == ~p"/admin/approvals"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Image has been approved."
      assert Repo.reload!(image).approved
    end

    test "as an admin approves the image", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      image = image_fixture(approved: false)

      conn = post(conn, ~p"/images/#{image}/approve")

      assert redirected_to(conn) == ~p"/admin/approvals"
      assert Repo.reload!(image).approved
    end

    # verify_not_approved halts with an error flash when the image is already
    # approved, rather than approving it twice.
    test "on an already-approved image redirects with the already-approved flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture(approved: true)

      conn = post(conn, ~p"/images/#{image}/approve")

      assert redirected_to(conn) == ~p"/admin/approvals"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Someone else already approved this image."
    end

    # Missing image locators resolve to not-found before authorization.
    # for which the moderator has no matching ability rule, taking the
    # not-authorized redirect.
    test "for an unknown image_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/images/999999999/approve")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    # NOTE: a non-integer image_id short-circuits to NotFoundPlug via the central
    # IntegerId guard before authorization runs.
    test "for a non-integer image_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/images/not-a-number/approve")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end
  end
end
