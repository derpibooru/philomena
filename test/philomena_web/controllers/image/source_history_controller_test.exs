defmodule PhilomenaWeb.Image.SourceHistoryControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ImagesFixtures

  alias Philomena.Repo

  describe "DELETE /images/:image_id/source_history" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture(source_url: "https://example.com/original")

      conn = delete(conn, ~p"/images/#{image}/source_history")

      assert redirected_to(conn) == ~p"/sessions/new"
      assert Repo.reload!(image).source_url == "https://example.com/original"
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture(source_url: "https://example.com/original")

      conn = delete(conn, ~p"/images/#{image}/source_history")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(image).source_url == "https://example.com/original"
    end

    test "as a moderator deletes the source history", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture(source_url: "https://example.com/original")

      conn = delete(conn, ~p"/images/#{image}/source_history")

      assert redirected_to(conn) == ~p"/images/#{image}"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Successfully deleted source history."

      assert Repo.reload!(image).source_url == nil
    end

    test "as an admin deletes the source history", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      image = image_fixture(source_url: "https://example.com/original")

      conn = delete(conn, ~p"/images/#{image}/source_history")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Successfully deleted source history."

      assert Repo.reload!(image).source_url == nil
    end

    test "for an unknown image_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = delete(conn, ~p"/images/999999999/source_history")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    # NOTE: a non-integer image_id short-circuits to NotFoundPlug via the central
    # IntegerId guard before authorization runs.
    test "for a non-integer image_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = delete(conn, ~p"/images/not-a-number/source_history")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end
  end
end
