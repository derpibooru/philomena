defmodule PhilomenaWeb.Image.FeatureControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Ecto.Query
  import Philomena.ImagesFixtures

  alias Philomena.ImageFeatures.ImageFeature
  alias Philomena.Repo

  defp featured?(image) do
    Repo.exists?(from f in ImageFeature, where: f.image_id == ^image.id)
  end

  describe "POST /images/:image_id/feature" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/feature")

      assert redirected_to(conn) == ~p"/sessions/new"
      refute featured?(image)
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/feature")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute featured?(image)
    end

    test "as a moderator features the image", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/feature")

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Image marked as featured image."
      assert featured?(image)
    end

    test "as an admin features the image", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/feature")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Image marked as featured image."
      assert featured?(image)
    end

    test "refuses to feature a deleted image", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture(hidden_from_users: true, deletion_reason: "Spam")

      conn = post(conn, ~p"/images/#{image}/feature")

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Cannot feature a deleted image."
      refute featured?(image)
    end

    test "for an unknown image_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/images/999999999/feature")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    # NOTE: a non-integer image_id short-circuits to NotFoundPlug via the central
    # IntegerId guard before authorization runs.
    test "for a non-integer image_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/images/not-a-number/feature")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end
  end
end
