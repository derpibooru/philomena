defmodule PhilomenaWeb.Image.DeleteControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # This controller is the moderation "hide/delete image" tool (the
  # user-facing hide is Image.HideController).

  import Philomena.ImagesFixtures

  alias Philomena.Repo

  describe "POST /images/:image_id/delete (hide)" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture()

      conn =
        post(conn, ~p"/images/#{image}/delete", %{"image" => %{"deletion_reason" => "Spam"}})

      assert redirected_to(conn) == ~p"/sessions/new"
      refute Repo.reload!(image).hidden_from_users
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()

      conn =
        post(conn, ~p"/images/#{image}/delete", %{"image" => %{"deletion_reason" => "Spam"}})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.reload!(image).hidden_from_users
    end

    test "as a moderator hides the image with the given reason", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn =
        post(conn, ~p"/images/#{image}/delete", %{
          "image" => %{"deletion_reason" => "Rule violation"}
        })

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Image successfully deleted."

      image = Repo.reload!(image)
      assert image.hidden_from_users
      assert image.deletion_reason == "Rule violation"
    end

    # Failure path: hide_changeset requires a deletion reason.
    test "with a blank deletion reason redirects with the error flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn =
        post(conn, ~p"/images/#{image}/delete", %{"image" => %{"deletion_reason" => ""}})

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Failed to delete image."
      refute Repo.reload!(image).hidden_from_users
    end

    test "for an unknown image_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(conn, ~p"/images/999999999/delete", %{"image" => %{"deletion_reason" => "Spam"}})

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end
  end

  describe "PATCH/PUT /images/:image_id/delete (update reason)" do
    test "as a moderator updates the deletion reason on a hidden image", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture(hidden_from_users: true, deletion_reason: "Original reason")

      conn =
        patch(conn, ~p"/images/#{image}/delete", %{
          "image" => %{"deletion_reason" => "Updated reason"}
        })

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Deletion reason updated."
      assert Repo.reload!(image).deletion_reason == "Updated reason"
    end

    test "PUT behaves like PATCH", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture(hidden_from_users: true, deletion_reason: "Original reason")

      conn =
        put(conn, ~p"/images/#{image}/delete", %{
          "image" => %{"deletion_reason" => "PUT reason"}
        })

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Repo.reload!(image).deletion_reason == "PUT reason"
    end

    # verify_deleted halts when the image is not currently hidden.
    test "on a non-deleted image redirects with the error flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn =
        patch(conn, ~p"/images/#{image}/delete", %{
          "image" => %{"deletion_reason" => "Whatever"}
        })

      assert redirected_to(conn) == ~p"/images/#{image}"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't update deletion reason."
    end

    # Failure path: a blank reason on a hidden image fails validation.
    test "with a blank deletion reason redirects with the error flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture(hidden_from_users: true, deletion_reason: "Original reason")

      conn =
        patch(conn, ~p"/images/#{image}/delete", %{"image" => %{"deletion_reason" => ""}})

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Couldn't update deletion reason."
      assert Repo.reload!(image).deletion_reason == "Original reason"
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture(hidden_from_users: true, deletion_reason: "Original reason")

      conn =
        patch(conn, ~p"/images/#{image}/delete", %{
          "image" => %{"deletion_reason" => "Updated reason"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(image).deletion_reason == "Original reason"
    end
  end

  describe "DELETE /images/:image_id/delete (restore)" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture(hidden_from_users: true, deletion_reason: "Spam")

      conn = delete(conn, ~p"/images/#{image}/delete")

      assert redirected_to(conn) == ~p"/sessions/new"
      assert Repo.reload!(image).hidden_from_users
    end

    test "rejects a regular user", %{conn: conn} do
      image = image_fixture(hidden_from_users: true, deletion_reason: "Spam")
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = delete(conn, ~p"/images/#{image}/delete")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(image).hidden_from_users
    end

    test "as a moderator restores a hidden image", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture(hidden_from_users: true, deletion_reason: "Spam")

      conn = delete(conn, ~p"/images/#{image}/delete")

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Image successfully restored."
      refute Repo.reload!(image).hidden_from_users
    end

    test "restoring a non-hidden image fails", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn = delete(conn, ~p"/images/#{image}/delete")

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Failed to restore image."
      refute Repo.reload!(image).hidden_from_users
    end

    # NOTE: a non-integer image_id short-circuits to NotFoundPlug via the central
    # IntegerId guard before authorization runs.
    test "for a non-integer image_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = delete(conn, ~p"/images/not-a-number/delete")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end
  end
end
