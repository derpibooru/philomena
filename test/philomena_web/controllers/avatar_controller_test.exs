defmodule PhilomenaWeb.AvatarControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures

  alias Philomena.Users
  alias Philomena.Repo
  alias Phoenix.Flash

  @png_fixture Path.absname("test/support/fixtures/files/upload-test.png")

  # A Plug.Upload whose tempfile is registered to the test process, the way
  # Plug.Parsers would provide it (same recipe as the image upload tests).
  defp png_upload do
    {:ok, path} = Plug.Upload.random_file("avatar-test")
    File.cp!(@png_fixture, path)
    %Plug.Upload{path: path, content_type: "image/png", filename: "upload-test.png"}
  end

  describe "GET /avatar/edit" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      conn = get(conn, ~p"/avatar/edit")
      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "renders the avatar form", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/avatar/edit")
      assert html_response(conn, 200) =~ "Editing Avatar - Derpibooru"
    end

    test "redirects banned users to the referrer with a flash", %{conn: conn} do
      user = banned_user_fixture()
      conn = conn |> log_in_user(user) |> get(~p"/avatar/edit")
      assert redirected_to(conn) == "/"
      assert Flash.get(conn.assigns.flash, :error) =~ "You are currently banned."
    end

    test "renders the avatar form without a fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(without_fingerprint(conn), ~p"/avatar/edit")

      assert html_response(conn, 200) =~ "Editing Avatar - Derpibooru"
    end
  end

  describe "PATCH /avatar" do
    setup :register_and_log_in_user

    test "uploads a new avatar", %{conn: conn, user: user} do
      conn = patch(conn, ~p"/avatar", %{"user" => %{"avatar" => png_upload()}})

      assert redirected_to(conn) == ~p"/avatar/edit"
      assert Flash.get(conn.assigns.flash, :info) =~ "Successfully updated avatar."

      # Only the avatar path column persists; the width/height/size/mime
      # fields on the schema are virtual and validation-only.
      assert Users.fetch_user_for_worker!(user.id).avatar =~ ~r/\.png$/
    end

    test "re-renders the form without an avatar file", %{conn: conn, user: user} do
      conn = patch(conn, ~p"/avatar", %{"user" => %{}})

      # NOTE: the failure branch re-renders edit.html without the :title
      # assign, so pin page content rather than the title.
      assert html_response(conn, 200) =~ "Your avatar"
      refute Users.fetch_user_for_worker!(user.id).avatar
    end

    test "redirects anonymous users to the login page" do
      conn = build_conn()
      conn = patch(conn, ~p"/avatar", %{"user" => %{}})
      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{
      conn: conn,
      user: user
    } do
      conn =
        patch(without_fingerprint(conn), ~p"/avatar", %{"user" => %{"avatar" => png_upload()}})

      assert redirected_to(conn) == "/"
      assert Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Users.fetch_user_for_worker!(user.id).avatar
    end
  end

  describe "PUT /avatar" do
    setup :register_and_log_in_user

    test "behaves like PATCH", %{conn: conn, user: user} do
      conn = put(conn, ~p"/avatar", %{"user" => %{"avatar" => png_upload()}})

      assert redirected_to(conn) == ~p"/avatar/edit"
      assert Users.fetch_user_for_worker!(user.id).avatar
    end
  end

  describe "DELETE /avatar" do
    setup :register_and_log_in_user

    test "removes the avatar", %{conn: conn, user: user} do
      user
      |> Ecto.Changeset.change(
        avatar: "2026/1/1/#{user.id}.png",
        avatar_mime_type: "image/png",
        avatar_width: 1,
        avatar_height: 1,
        avatar_size: 1024
      )
      |> Repo.update!()

      conn = delete(conn, ~p"/avatar")

      assert redirected_to(conn) == ~p"/avatar/edit"
      assert Flash.get(conn.assigns.flash, :info) =~ "Successfully removed avatar."
      refute Users.fetch_user_for_worker!(user.id).avatar
    end

    test "succeeds even when no avatar is set", %{conn: conn} do
      conn = delete(conn, ~p"/avatar")
      assert redirected_to(conn) == ~p"/avatar/edit"
      assert Flash.get(conn.assigns.flash, :info) =~ "Successfully removed avatar."
    end

    test "redirects anonymous users to the login page" do
      conn = build_conn() |> delete(~p"/avatar")
      assert redirected_to(conn) == ~p"/sessions/new"
    end
  end
end
