defmodule PhilomenaWeb.Tag.ImageControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # :update drives the tag spoiler image through the real media pipeline
  # (analysis is synchronous, the S3 persist goes through the ex_aws stub).
  # All three actions authorize :edit on the tag, so any moderator can
  # reach them. Tags are slug-keyed, so there is no non-integer-id crash.

  import Philomena.ImagesFixtures
  import Philomena.TagsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Repo
  alias Philomena.Tags.Tag

  describe "GET /tags/:tag_id/image/edit" do
    test "is a login redirect for anonymous users", %{conn: conn} do
      tag = tag_fixture()
      conn = get(conn, ~p"/tags/#{tag}/image/edit")

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "is rejected for regular users", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, confirmed_user_fixture())
      conn = get(conn, ~p"/tags/#{tag}/image/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
    end

    test "renders the edit form for a moderator", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, moderator_user_fixture())
      conn = get(conn, ~p"/tags/#{tag}/image/edit")

      assert html_response(conn, 200) =~ "Editing Tag Spoiler Image"
    end

    test "renders the edit form for a moderator without a fingerprint", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, moderator_user_fixture())
      conn = get(without_fingerprint(conn), ~p"/tags/#{tag}/image/edit")

      assert html_response(conn, 200) =~ "Editing Tag Spoiler Image"
    end
  end

  describe "PUT/PATCH /tags/:tag_id/image (update)" do
    test "is a login redirect for anonymous users", %{conn: conn} do
      tag = tag_fixture()
      conn = put(conn, ~p"/tags/#{tag}/image", %{"tag" => %{"image" => png_upload()}})

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "is rejected for regular users", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, confirmed_user_fixture())
      conn = put(conn, ~p"/tags/#{tag}/image", %{"tag" => %{"image" => png_upload()}})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
    end

    test "a moderator uploads a spoiler image (PATCH)", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, moderator_user_fixture())

      conn = patch(conn, ~p"/tags/#{tag}/image", %{"tag" => %{"image" => png_upload()}})

      assert redirected_to(conn) == ~p"/tags/#{tag}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Tag image successfully updated"

      tag = Repo.get!(Tag, tag.id)
      assert tag.image
      assert tag.image_mime_type == "image/png"
    end

    test "a moderator uploads a spoiler image (PUT)", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, moderator_user_fixture())

      conn = put(conn, ~p"/tags/#{tag}/image", %{"tag" => %{"image" => png_upload()}})

      assert redirected_to(conn) == ~p"/tags/#{tag}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Tag image successfully updated"

      tag = Repo.get!(Tag, tag.id)
      assert tag.image
      assert tag.image_mime_type == "image/png"
    end

    test "an update with no file re-renders the form", %{conn: conn} do
      # NOTE: the update/2 error branch now matches {:error, changeset} and
      # re-renders edit.html (200) rather than raising CaseClauseError.
      tag = tag_fixture()
      conn = log_in_user(conn, moderator_user_fixture())

      conn = patch(conn, ~p"/tags/#{tag}/image", %{"tag" => %{}})

      assert html_response(conn, 200) =~ "Update tag image"
    end

    test "an unknown slug takes the not-found redirect", %{conn: conn} do
      conn = log_in_user(conn, moderator_user_fixture())
      conn = patch(conn, ~p"/tags/nonexistent-tag/image", %{"tag" => %{"image" => png_upload()}})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, moderator_user_fixture())

      conn =
        patch(without_fingerprint(conn), ~p"/tags/#{tag}/image", %{
          "tag" => %{"image" => png_upload()}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.get!(Tag, tag.id).image
    end
  end

  describe "DELETE /tags/:tag_id/image" do
    test "is a login redirect for anonymous users", %{conn: conn} do
      tag = tag_fixture()
      conn = delete(conn, ~p"/tags/#{tag}/image")

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "is rejected for regular users", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, confirmed_user_fixture())
      conn = delete(conn, ~p"/tags/#{tag}/image")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
    end

    test "a moderator removes the spoiler image", %{conn: conn} do
      tag = tag_fixture() |> Ecto.Changeset.change(image: "2024/1/1/abc.png") |> Repo.update!()
      conn = log_in_user(conn, moderator_user_fixture())

      conn = delete(conn, ~p"/tags/#{tag}/image")

      assert redirected_to(conn) == ~p"/tags/#{tag}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Tag image successfully removed"
      assert Repo.get!(Tag, tag.id).image == nil
    end

    test "an unknown slug takes the not-found redirect", %{conn: conn} do
      conn = log_in_user(conn, moderator_user_fixture())
      conn = delete(conn, ~p"/tags/nonexistent-tag/image")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end
end
