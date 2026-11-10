defmodule PhilomenaWeb.Gallery.ImageControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # The image id travels in the request body, not the path (the route is a
  # singleton).

  import Ecto.Query
  import Philomena.GalleriesFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Galleries.Interaction
  alias Philomena.Repo

  test "anonymous requests redirect to the login page", %{conn: conn} do
    for request <- [
          post(conn, ~p"/galleries/1/images", %{"image_id" => "1"}),
          delete(conn, ~p"/galleries/1/images", %{"image_id" => "1"})
        ] do
      assert redirected_to(request) == ~p"/sessions/new"

      assert Phoenix.Flash.get(request.assigns.flash, :error) ==
               "You must log in to access this page."
    end
  end

  describe "POST /galleries/:gallery_id/images" do
    test "adds the image to the gallery as its owner", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      gallery = gallery_fixture(user)
      image = image_fixture()

      conn = post(conn, ~p"/galleries/#{gallery}/images", %{"image_id" => to_string(image.id)})

      assert json_response(conn, 200) == %{}

      assert Repo.exists?(
               from i in Interaction,
                 where: i.gallery_id == ^gallery.id and i.image_id == ^image.id
             )

      assert Repo.reload!(gallery).image_count == 1
    end

    test "responds conflict when the image is already in the gallery", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      gallery = gallery_fixture(user)
      image = image_fixture()
      gallery_image_fixture(gallery, image)

      conn = post(conn, ~p"/galleries/#{gallery}/images", %{"image_id" => to_string(image.id)})

      assert json_response(conn, 409) == %{}
      assert Repo.reload!(gallery).image_count == 1
    end

    test "redirects with the not-found flash for an unknown image id", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      gallery = gallery_fixture(user)

      conn = post(conn, ~p"/galleries/#{gallery}/images", %{"image_id" => "999999999"})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "redirects other users with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      gallery = gallery_fixture(confirmed_user_fixture())
      image = image_fixture()

      conn = post(conn, ~p"/galleries/#{gallery}/images", %{"image_id" => to_string(image.id)})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.aggregate(Interaction, :count) == 0
    end

    test "redirects banned users with the ban flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

      conn = post(conn, ~p"/galleries/1/images", %{"image_id" => "1"})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
    end
  end

  describe "DELETE /galleries/:gallery_id/images" do
    test "removes the image from the gallery as its owner", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      gallery = gallery_fixture(user)
      image = image_fixture()
      gallery_image_fixture(gallery, image)

      conn =
        delete(conn, ~p"/galleries/#{gallery}/images", %{"image_id" => to_string(image.id)})

      assert json_response(conn, 200) == %{}

      refute Repo.exists?(
               from i in Interaction,
                 where: i.gallery_id == ^gallery.id and i.image_id == ^image.id
             )

      assert Repo.reload!(gallery).image_count == 0
    end

    test "responds bad request when the image is not in the gallery", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      gallery = gallery_fixture(user)
      image = image_fixture()

      conn =
        delete(conn, ~p"/galleries/#{gallery}/images", %{"image_id" => to_string(image.id)})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
      assert Repo.reload!(gallery).image_count == 0
    end

    test "redirects other users with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      owner = confirmed_user_fixture()
      gallery = gallery_fixture(owner)
      image = image_fixture()
      gallery_image_fixture(gallery, image)

      conn =
        delete(conn, ~p"/galleries/#{gallery}/images", %{"image_id" => to_string(image.id)})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.aggregate(Interaction, :count) == 1
    end
  end
end
