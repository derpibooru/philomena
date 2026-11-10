defmodule PhilomenaWeb.Image.HashControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ImagesFixtures

  alias Philomena.Repo

  describe "DELETE /images/:image_id/hash" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture()

      conn = delete(conn, ~p"/images/#{image}/hash")

      assert redirected_to(conn) == ~p"/sessions/new"
      assert Repo.reload!(image).image_orig_sha512_hash != nil
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()

      conn = delete(conn, ~p"/images/#{image}/hash")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(image).image_orig_sha512_hash != nil
    end

    test "as a moderator clears the original hash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn = delete(conn, ~p"/images/#{image}/hash")

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully cleared hash."
      assert Repo.reload!(image).image_orig_sha512_hash == nil
    end

    test "as an admin clears the original hash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      image = image_fixture()

      conn = delete(conn, ~p"/images/#{image}/hash")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully cleared hash."
      assert Repo.reload!(image).image_orig_sha512_hash == nil
    end

    test "for an unknown image_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = delete(conn, ~p"/images/999999999/hash")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    # NOTE: a non-integer image_id short-circuits to NotFoundPlug via the central
    # IntegerId guard before authorization runs.
    test "for a non-integer image_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = delete(conn, ~p"/images/not-a-number/hash")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end
  end
end
