defmodule PhilomenaWeb.Admin.Badge.ImageControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.BadgesFixtures

  alias Philomena.Badges.Badge
  alias Philomena.Repo

  describe "GET /admin/badges/:badge_id/image/edit" do
    test "redirects anonymous users to login", %{conn: conn} do
      badge = badge_fixture()
      conn = get(conn, ~p"/admin/badges/#{badge}/image/edit")
      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "rejects a regular user", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/badges/#{badge}/image/edit")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "rejects a plain moderator", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/badges/#{badge}/image/edit")
      assert redirected_to(conn) == "/"
    end

    test "renders the form for a Badge-role moderator", %{conn: conn} do
      badge = badge_fixture()
      conn = log_in_role_moderator(conn, "Badge")
      conn = get(conn, ~p"/admin/badges/#{badge}/image/edit")
      assert html_response(conn, 200) =~ "Upload SVG image"
    end

    test "renders the form for an admin", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/badges/#{badge}/image/edit")
      response = html_response(conn, 200)
      assert response =~ "Editing Badge - Derpibooru"
      assert response =~ "Edit Badge"
    end

    test "redirects with a not-found flash for an unknown id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/badges/#{2_000_000_000}/image/edit")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "redirects with a not-found flash for a non-integer id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = get(conn, ~p"/admin/badges/not-a-number/image/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "renders the form for an admin without a fingerprint", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = get(without_fingerprint(conn), ~p"/admin/badges/#{badge}/image/edit")

      assert html_response(conn, 200) =~ "Editing Badge - Derpibooru"
    end
  end

  describe "PATCH /admin/badges/:badge_id/image (update)" do
    test "rejects a plain moderator", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(conn, ~p"/admin/badges/#{badge}/image", %{"badge" => %{"image" => svg_upload()}})

      assert redirected_to(conn) == "/"
    end

    test "updates the badge image as an admin", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        patch(conn, ~p"/admin/badges/#{badge}/image", %{"badge" => %{"image" => svg_upload()}})

      assert redirected_to(conn) == ~p"/admin/badges"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Badge updated successfully."
      # NOTE: The image column is rewritten to the pipeline-generated key, so
      # the "test.svg" the fixture inserted is replaced.
      refute Repo.get(Badge, badge.id).image == "test.svg"
    end

    test "updates the badge image as a Badge-role moderator", %{conn: conn} do
      badge = badge_fixture()
      conn = log_in_role_moderator(conn, "Badge")

      conn =
        patch(conn, ~p"/admin/badges/#{badge}/image", %{"badge" => %{"image" => svg_upload()}})

      assert redirected_to(conn) == ~p"/admin/badges"
    end

    # NOTE: the update/2 error branch now matches {:error, changeset} and
    # re-renders edit.html (200) rather than raising CaseClauseError.
    test "re-renders the form on a validation failure (missing image)", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = patch(conn, ~p"/admin/badges/#{badge}/image", %{"badge" => %{}})

      response = html_response(conn, 200)
      assert response =~ "Upload SVG image"
      assert response =~ "Oops, something went wrong!"
      assert Repo.get(Badge, badge.id).image == "test.svg"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        patch(without_fingerprint(conn), ~p"/admin/badges/#{badge}/image", %{
          "badge" => %{"image" => svg_upload()}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get(Badge, badge.id).image == badge.image
    end
  end

  describe "PUT /admin/badges/:badge_id/image (update)" do
    test "updates the badge image as an admin", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = put(conn, ~p"/admin/badges/#{badge}/image", %{"badge" => %{"image" => svg_upload()}})
      assert redirected_to(conn) == ~p"/admin/badges"
    end
  end
end
