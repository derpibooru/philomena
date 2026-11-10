defmodule PhilomenaWeb.Admin.Advert.ImageControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.AdvertsFixtures

  alias Philomena.Adverts.Advert
  alias Philomena.Repo

  describe "GET /admin/adverts/:advert_id/image/edit" do
    test "redirects anonymous users to login", %{conn: conn} do
      advert = advert_fixture()
      conn = get(conn, ~p"/admin/adverts/#{advert}/image/edit")
      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "rejects a regular user", %{conn: conn} do
      advert = advert_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/adverts/#{advert}/image/edit")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "rejects a plain moderator", %{conn: conn} do
      advert = advert_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/adverts/#{advert}/image/edit")
      assert redirected_to(conn) == "/"
    end

    test "renders the form for an Advert-role moderator", %{conn: conn} do
      advert = advert_fixture()
      conn = log_in_role_moderator(conn, "Advert")
      conn = get(conn, ~p"/admin/adverts/#{advert}/image/edit")
      assert html_response(conn, 200) =~ "Upload image"
    end

    test "renders the form for an admin", %{conn: conn} do
      advert = advert_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/adverts/#{advert}/image/edit")
      response = html_response(conn, 200)
      assert response =~ "Editing Advert - Derpibooru"
      assert response =~ "Edit Advert"
    end

    test "redirects with a not-found flash for an unknown id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/adverts/#{2_000_000_000}/image/edit")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "redirects with a not-found flash for a non-integer id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = get(conn, ~p"/admin/adverts/not-a-number/image/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "renders the form for an admin without a fingerprint", %{conn: conn} do
      advert = advert_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = get(without_fingerprint(conn), ~p"/admin/adverts/#{advert}/image/edit")

      assert html_response(conn, 200) =~ "Editing Advert - Derpibooru"
    end
  end

  describe "PATCH /admin/adverts/:advert_id/image (update)" do
    test "rejects a plain moderator", %{conn: conn} do
      advert = advert_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(conn, ~p"/admin/adverts/#{advert}/image", %{"advert" => %{"image" => png_upload()}})

      assert redirected_to(conn) == "/"
    end

    test "updates the advert image as an admin", %{conn: conn} do
      advert = advert_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        patch(conn, ~p"/admin/adverts/#{advert}/image", %{"advert" => %{"image" => png_upload()}})

      assert redirected_to(conn) == ~p"/admin/adverts"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Advert was successfully updated."
      # NOTE: The image column is rewritten to the pipeline-generated key.
      refute Repo.get(Advert, advert.id).image == "test.png"
    end

    test "updates the advert image as an Advert-role moderator", %{conn: conn} do
      advert = advert_fixture()
      conn = log_in_role_moderator(conn, "Advert")

      conn =
        patch(conn, ~p"/admin/adverts/#{advert}/image", %{"advert" => %{"image" => png_upload()}})

      assert redirected_to(conn) == ~p"/admin/adverts"
    end

    # NOTE: `update_advert_image/2` returns `{:error, changeset}` and the
    # controller matches it, so an image failing the dimension validations
    # re-renders the edit form (200), unlike the badge image controller which
    # crashes on the analogous failure.
    test "re-renders the edit form on a dimension-validation failure", %{conn: conn} do
      advert = advert_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        patch(conn, ~p"/admin/adverts/#{advert}/image", %{
          "advert" => %{"image" => undersized_png_upload()}
        })

      assert html_response(conn, 200) =~ "Edit Advert"
      assert Repo.get(Advert, advert.id).image == "test.png"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      advert = advert_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        patch(without_fingerprint(conn), ~p"/admin/adverts/#{advert}/image", %{
          "advert" => %{"image" => png_upload()}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get(Advert, advert.id).image == advert.image
    end
  end

  describe "PUT /admin/adverts/:advert_id/image (update)" do
    test "updates the advert image as an admin", %{conn: conn} do
      advert = advert_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        put(conn, ~p"/admin/adverts/#{advert}/image", %{"advert" => %{"image" => png_upload()}})

      assert redirected_to(conn) == ~p"/admin/adverts"
    end
  end
end
