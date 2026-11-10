defmodule PhilomenaWeb.Image.AnonymousControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ImagesFixtures

  alias Philomena.Repo

  defp anonymous?(image), do: Repo.reload!(image).anonymous

  describe "POST /images/:image_id/anonymous" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture(anonymous: false)

      conn = post(conn, ~p"/images/#{image}/anonymous")

      assert redirected_to(conn) == ~p"/sessions/new"
      refute anonymous?(image)
    end

    # NOTE: the context authorizes `:show, :identity_metadata`, which a regular user
    # lacks, so they get the authorization redirect.
    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture(anonymous: false)

      conn = post(conn, ~p"/images/#{image}/anonymous")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute anonymous?(image)
    end

    test "as a moderator hides the author", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture(anonymous: false)

      conn = post(conn, ~p"/images/#{image}/anonymous")

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully updated anonymity."
      assert anonymous?(image)
    end

    test "as an admin hides the author", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      image = image_fixture(anonymous: false)

      conn = post(conn, ~p"/images/#{image}/anonymous")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully updated anonymity."
      assert anonymous?(image)
    end

    # Missing image locators resolve to not-found before authorization.
    # authorized on it, so :create returns not_found - an unknown id redirects
    # rather than crashing in update_image_anonymous.
    test "for an unknown image_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/images/999999999/anonymous")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    # NOTE: a non-integer image_id short-circuits to NotFoundPlug via the central
    # IntegerId guard.
    test "for a non-integer image_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/images/not-a-number/anonymous")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end
  end

  describe "DELETE /images/:image_id/anonymous" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture(anonymous: true)

      conn = delete(conn, ~p"/images/#{image}/anonymous")

      assert redirected_to(conn) == ~p"/sessions/new"
      assert anonymous?(image)
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture(anonymous: true)

      conn = delete(conn, ~p"/images/#{image}/anonymous")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert anonymous?(image)
    end

    test "as a moderator reveals the author", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture(anonymous: true)

      conn = delete(conn, ~p"/images/#{image}/anonymous")

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully updated anonymity."
      refute anonymous?(image)
    end

    test "as an admin reveals the author", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      image = image_fixture(anonymous: true)

      conn = delete(conn, ~p"/images/#{image}/anonymous")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully updated anonymity."
      refute anonymous?(image)
    end

    # Missing image locators resolve to not-found before authorization.
    # authorized on it, so :delete returns not_found - an unknown id redirects
    # rather than crashing.
    test "for an unknown image_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = delete(conn, ~p"/images/999999999/anonymous")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    # NOTE: a non-integer image_id short-circuits to NotFoundPlug via the central
    # IntegerId guard.
    test "for a non-integer image_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = delete(conn, ~p"/images/not-a-number/anonymous")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end
  end
end
