defmodule PhilomenaWeb.Image.FileControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # `Images.update_image_file/3` drives the media pipeline synchronously
  # (analyze, persist to the stubbed S3, enqueue the dead
  # ThumbnailWorker/reindex jobs), with no spawned upload process, so this
  # file stays `async: true`.

  import Philomena.ImagesFixtures

  alias Philomena.Repo

  describe "PATCH/PUT /images/:image_id/file" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture()

      conn = put(conn, ~p"/images/#{image}/file", %{"image" => %{"image" => png_upload()}})

      assert redirected_to(conn) == ~p"/sessions/new"
      # Not touched - the plug pipeline halts before the action.
      assert Repo.reload!(image).processed == true
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()

      conn = put(conn, ~p"/images/#{image}/file", %{"image" => %{"image" => png_upload()}})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(image).processed == true
    end

    test "as a moderator replaces the file", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn = put(conn, ~p"/images/#{image}/file", %{"image" => %{"image" => png_upload()}})

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully updated file."

      # create_image_repair marks the image for reprocessing.
      reloaded = Repo.reload!(image)
      assert reloaded.processed == false
      assert reloaded.thumbnails_generated == false

      # On success the stored hash becomes the replacement file's own hash.
      assert reloaded.image_orig_sha512_hash != nil
      assert reloaded.image_orig_sha512_hash != image.image_orig_sha512_hash
      assert reloaded.image_orig_sha512_hash == png_upload_sha512()
    end

    test "as an admin replaces the file", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      image = image_fixture()

      conn = put(conn, ~p"/images/#{image}/file", %{"image" => %{"image" => png_upload()}})

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully updated file."
      assert Repo.reload!(image).processed == false
    end

    # The dedup check in image_changeset excludes the image being updated, so
    # re-uploading an image's *own* current file (byte-identical replacement,
    # same orig_sha512_hash) is not treated as a duplicate and succeeds. This
    # is the case the removed pre-emptive remove_hash used to make room for.
    test "as a moderator replacing with a byte-identical copy of its own file succeeds", %{
      conn: conn
    } do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      sha = png_upload_sha512()
      image = image_fixture(image_sha512_hash: sha, image_orig_sha512_hash: sha)

      conn = put(conn, ~p"/images/#{image}/file", %{"image" => %{"image" => png_upload()}})

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully updated file."

      reloaded = Repo.reload!(image)
      assert reloaded.processed == false
      assert reloaded.thumbnails_generated == false
      # Same file, same hash - the replacement went through.
      assert reloaded.image_orig_sha512_hash == sha
    end

    # A file that matches a *different* image's fingerprint is still rejected as
    # a duplicate (image_changeset adds the "has already been uploaded" error),
    # so update_image_file returns an error and the target image is left untouched -
    # its own fingerprint preserved.
    test "as a moderator replacing with a file already uploaded as another image fails", %{
      conn: conn
    } do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      dup_sha = png_upload_sha512()
      _other = image_fixture(image_sha512_hash: dup_sha, image_orig_sha512_hash: dup_sha)
      image = image_fixture()

      conn = put(conn, ~p"/images/#{image}/file", %{"image" => %{"image" => png_upload()}})

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Failed to update file!"

      reloaded = Repo.reload!(image)
      # The target keeps its own fingerprint and file.
      assert reloaded.image_orig_sha512_hash == image.image_orig_sha512_hash
      assert reloaded.processed == true
    end

    test "as a moderator replaces a hidden image", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      image =
        image_fixture(
          hidden_from_users: true,
          hidden_image_key: "hidden-key",
          deletion_reason: "Spam"
        )

      conn = put(conn, ~p"/images/#{image}/file", %{"image" => %{"image" => png_upload()}})

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully updated file."

      reloaded = Repo.reload!(image)
      assert reloaded.hidden_from_users
      assert reloaded.processed == false
      assert reloaded.thumbnails_generated == false
      assert reloaded.image_orig_sha512_hash == png_upload_sha512()
    end

    # update_image_file re-renders the "Failed to update file!" error branch on a
    # request with no file (image_changeset's validate_required(:image) fails).
    # The action goes straight to update_image_file, so a failed replacement leaves
    # the image untouched - crucially the dedup fingerprint is preserved.
    test "without a file redirects with the failure flash and preserves the hash", %{
      conn: conn
    } do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn = put(conn, ~p"/images/#{image}/file", %{"image" => %{}})

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Failed to update file!"

      reloaded = Repo.reload!(image)
      # The hash is untouched - a failed replace no longer wipes the fingerprint.
      assert reloaded.image_orig_sha512_hash == image.image_orig_sha512_hash
      # The file itself was not replaced.
      assert reloaded.processed == true
    end

    test "for an unknown image_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        put(conn, ~p"/images/999999999/file", %{"image" => %{"image" => png_upload()}})

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    # NOTE: a non-integer image_id short-circuits to NotFoundPlug via the central
    # IntegerId guard before authorization runs.
    test "for a non-integer image_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = put(conn, ~p"/images/not-a-number/file", %{"image" => %{"image" => png_upload()}})

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end
  end
end
