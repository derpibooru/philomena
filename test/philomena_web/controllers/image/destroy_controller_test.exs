defmodule PhilomenaWeb.Image.DestroyControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # This is the hard-delete (content destruction) tool, gated on the
  # `:destroy` ability, which plain moderators lack.

  import Philomena.ImagesFixtures

  alias Philomena.Repo

  defp deleted_image do
    image_fixture(hidden_from_users: true, deletion_reason: "Spam")
  end

  describe "POST /images/:image_id/destroy" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = deleted_image()

      conn = post(conn, ~p"/images/#{image}/destroy")

      assert redirected_to(conn) == ~p"/sessions/new"
      assert Repo.reload!(image).image != nil
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = deleted_image()

      conn = post(conn, ~p"/images/#{image}/destroy")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(image).image != nil
    end

    # NOTE: unlike the other image mod tools, a plain moderator CANNOT destroy
    # an image - the :destroy ability requires an Image-admin role_map grant.
    test "rejects a plain moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = deleted_image()

      conn = post(conn, ~p"/images/#{image}/destroy")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(image).image != nil
    end

    test "as an Image-admin role_map moderator destroys the image contents", %{conn: conn} do
      conn = log_in_role_moderator(conn, "Image")
      image = deleted_image()

      conn = post(conn, ~p"/images/#{image}/destroy")

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Image contents destroyed."

      # NOTE: removed_image is a virtual field, so only the image column being
      # nulled is observable after reload.
      assert Repo.reload!(image).image == nil
    end

    test "as an admin destroys the image contents", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      image = deleted_image()

      conn = post(conn, ~p"/images/#{image}/destroy")

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Image contents destroyed."
      assert Repo.reload!(image).image == nil
    end

    test "on a non-deleted image redirects with an error flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/destroy")

      assert redirected_to(conn) == ~p"/images/#{image}"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Failed to destroy image."

      assert Repo.reload!(image).image != nil
    end

    # Missing image locators resolve to not-found before authorization.
    # for which the role_map moderator has no matching rule.
    test "for an unknown image_id redirects with the not-found flash", %{conn: conn} do
      conn = log_in_role_moderator(conn, "Image")

      conn = post(conn, ~p"/images/999999999/destroy")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    # NOTE: a non-integer image_id short-circuits to NotFoundPlug via the central
    # IntegerId guard before authorization runs.
    test "for a non-integer image_id redirects with the not-found flash", %{conn: conn} do
      conn = log_in_role_moderator(conn, "Image")

      conn = post(conn, ~p"/images/not-a-number/destroy")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end
  end
end
