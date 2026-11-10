defmodule PhilomenaWeb.GalleryControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  @moduletag :search

  import Ecto.Query
  import Philomena.GalleriesFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers
  alias Philomena.Galleries.Gallery
  alias Philomena.Images.Image

  setup do
    Search.clear_index!(Gallery)
    Search.clear_index!(Image)
    :ok
  end

  describe "GET /galleries" do
    test "an empty gallery parameter uses the default gallery query", %{conn: conn} do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(user, title: "Test Empty Query Gallery")
      SearchHelpers.reindex_all!(Gallery)

      conn = get(conn, ~p"/galleries?gallery=")

      assert html_response(conn, 200) =~ ~p"/galleries/#{gallery.id}"
    end

    test "lists galleries for anonymous users", %{conn: conn} do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(user, title: "Test Listed Gallery")
      SearchHelpers.reindex_all!(Gallery)

      conn = get(conn, ~p"/galleries")
      response = html_response(conn, 200)

      assert response =~ "Galleries - Derpibooru"
      assert response =~ "Test Listed Gallery"
      assert response =~ ~p"/galleries/#{gallery.id}"
    end

    test "filters galleries by title", %{conn: conn} do
      user = confirmed_user_fixture()
      _wanted = gallery_fixture(user, title: "Test Wanted Gallery")
      _other = gallery_fixture(user, title: "Test Unrelated Gallery")
      SearchHelpers.reindex_all!(Gallery)

      conn = get(conn, ~p"/galleries?#{[gallery: [title: "wanted"]]}")
      response = html_response(conn, 200)

      assert response =~ "Test Wanted Gallery"
      refute response =~ "Test Unrelated Gallery"
    end

    test "renders with no galleries", %{conn: conn} do
      conn = get(conn, ~p"/galleries")

      assert html_response(conn, 200) =~ "Galleries - Derpibooru"
    end
  end

  describe "GET /galleries/:id" do
    test "renders a gallery and its images for anonymous users", %{conn: conn} do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(user, title: "Test Shown Gallery")
      image = image_fixture()

      gallery_image_fixture(gallery, image)
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/galleries/#{gallery}")
      response = html_response(conn, 200)

      assert response =~ "Showing Gallery - Derpibooru"
      assert response =~ "Test Shown Gallery"
      assert response =~ ~p"/images/#{image.id}"
    end

    test "links images in gallery order so image navigation stays in the gallery",
         %{conn: conn} do
      gallery = gallery_fixture(confirmed_user_fixture())
      first = image_fixture()
      second = image_fixture()
      gallery_image_fixture(gallery, first)
      gallery_image_fixture(gallery, second)
      image_fixture()
      SearchHelpers.reindex_all!(Image)

      response = conn |> get(~p"/galleries/#{gallery}") |> html_response(200)

      [query_string] =
        Regex.run(~r{/images/#{second.id}\?([^"]+)"}, response, capture: :all_but_first)

      query_string = String.replace(query_string, "&amp;", "&")
      assert query_string =~ "sf=gallery_id%3A#{gallery.id}"

      conn = get(build_conn(), "/images/#{second.id}/navigate?rel=next&#{query_string}")

      assert redirected_to(conn) =~ ~p"/images/#{first.id}"
    end

    test "renders a page number far past the search window", %{conn: conn} do
      gallery = gallery_fixture(confirmed_user_fixture(), title: "Test Deep Gallery")

      conn = get(conn, ~p"/galleries/#{gallery}?page=128739609")

      assert html_response(conn, 200) =~ "Test Deep Gallery"
    end

    test "renders an empty gallery", %{conn: conn} do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(user, title: "Test Empty Gallery")

      conn = get(conn, ~p"/galleries/#{gallery}")
      response = html_response(conn, 200)

      assert response =~ "Showing Gallery - Derpibooru"
      assert response =~ "Test Empty Gallery"
    end

    test "shows when the gallery was created", %{conn: conn} do
      gallery = gallery_fixture(confirmed_user_fixture())

      Gallery
      |> where(id: ^gallery.id)
      |> Philomena.Repo.update_all(set: [created_at: ~U[2020-01-01 00:00:00Z]])

      conn = get(conn, ~p"/galleries/#{gallery}")

      assert html_response(conn, 200) =~ ~s(datetime="2020-01-01T00:00:00Z")
    end

    test "renders a gallery for logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      gallery = gallery_fixture(confirmed_user_fixture())

      conn = get(conn, ~p"/galleries/#{gallery}")

      assert html_response(conn, 200) =~ "Showing Gallery - Derpibooru"
    end

    test "renders management controls for the gallery owner", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      gallery = gallery_fixture(user)

      response = html_response(get(conn, ~p"/galleries/#{gallery}"), 200)

      assert response =~ ~p"/galleries/#{gallery}/edit"
      assert response =~ "Rearrange"
      assert response =~ "Save"
      assert response =~ ~p"/galleries/#{gallery}/order"
      assert response =~ "Delete"
      assert response =~ ~p"/galleries/#{gallery}"
    end

    test "hides management controls from another user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      gallery = gallery_fixture(confirmed_user_fixture())

      response = html_response(get(conn, ~p"/galleries/#{gallery}"), 200)

      refute response =~ ~p"/galleries/#{gallery}/edit"
      refute response =~ "Rearrange"
      refute response =~ "Save"
      refute response =~ ~p"/galleries/#{gallery}/order"
      refute response =~ "Delete"
    end

    test "renders management controls for a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      gallery = gallery_fixture(confirmed_user_fixture())

      response = html_response(get(conn, ~p"/galleries/#{gallery}"), 200)

      assert response =~ ~p"/galleries/#{gallery}/edit"
      assert response =~ "Rearrange"
      assert response =~ "Delete"
    end

    test "redirects to / for an unknown id", %{conn: conn} do
      conn = get(conn, ~p"/galleries/999999999")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end

  describe "GET /galleries/new" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      conn = get(conn, ~p"/galleries/new")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "renders the form for logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      response = html_response(get(conn, ~p"/galleries/new"), 200)

      assert response =~ "New Gallery - Derpibooru"
      assert response =~ "Create a Gallery"
    end

    test "redirects banned users with the ban flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

      conn = get(conn, ~p"/galleries/new")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
    end

    test "renders the form without a fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(without_fingerprint(conn), ~p"/galleries/new")

      assert html_response(conn, 200) =~ "New Gallery - Derpibooru"
    end
  end

  describe "POST /galleries" do
    test "creates the gallery and redirects to it", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      thumbnail = image_fixture()

      conn =
        post(conn, ~p"/galleries", %{
          "gallery" => %{
            "title" => "A new test gallery",
            "thumbnail_id" => to_string(thumbnail.id),
            "spoiler_warning" => "",
            "description" => "Test gallery description"
          }
        })

      gallery = Philomena.Repo.one!(from g in Gallery, where: g.user_id == ^user.id)

      assert redirected_to(conn) == ~p"/galleries/#{gallery}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Gallery successfully created."
      assert gallery.title == "A new test gallery"
      assert gallery.thumbnail_id == thumbnail.id
    end

    test "re-renders the form when the title is blank", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      thumbnail = image_fixture()

      conn =
        post(conn, ~p"/galleries", %{
          "gallery" => %{"title" => "", "thumbnail_id" => to_string(thumbnail.id)}
        })

      response = html_response(conn, 200)
      assert response =~ "Create a Gallery"
      refute Philomena.Repo.exists?(from g in Gallery, where: g.user_id == ^user.id)
    end

    test "redirects banned users with the ban flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

      conn = post(conn, ~p"/galleries", %{})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn =
        post(without_fingerprint(conn), ~p"/galleries", %{
          "gallery" => %{
            "title" => "A new test gallery",
            "thumbnail_id" => to_string(image_fixture().id)
          }
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Philomena.Repo.exists?(from g in Gallery, where: g.user_id == ^user.id)
    end
  end

  describe "GET /galleries/:id/edit" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      gallery = gallery_fixture(confirmed_user_fixture())

      conn = get(conn, ~p"/galleries/#{gallery}/edit")

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "renders the form for the gallery's owner", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      gallery = gallery_fixture(user)

      response = html_response(get(conn, ~p"/galleries/#{gallery}/edit"), 200)

      assert response =~ "Editing Gallery - Derpibooru"
    end

    test "redirects other users with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      gallery = gallery_fixture(confirmed_user_fixture())

      conn = get(conn, ~p"/galleries/#{gallery}/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "renders the form for a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      gallery = gallery_fixture(confirmed_user_fixture())

      response = html_response(get(conn, ~p"/galleries/#{gallery}/edit"), 200)

      assert response =~ "Editing Gallery - Derpibooru"
    end

    test "redirects to / with the not-found flash for an unknown id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/galleries/999999999/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "renders the form for the owner without a fingerprint", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      gallery = gallery_fixture(user)

      conn = get(without_fingerprint(conn), ~p"/galleries/#{gallery}/edit")

      assert html_response(conn, 200) =~ "Editing Gallery - Derpibooru"
    end
  end

  describe "PATCH /galleries/:id" do
    test "updates the gallery as its owner", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      gallery = gallery_fixture(user)

      conn =
        patch(conn, ~p"/galleries/#{gallery}", %{
          "gallery" => %{"title" => "Renamed test gallery"}
        })

      assert redirected_to(conn) == ~p"/galleries/#{gallery}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Gallery successfully updated."
      assert Philomena.Repo.reload!(gallery).title == "Renamed test gallery"
    end

    test "PUT also updates the gallery", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      gallery = gallery_fixture(user)

      conn =
        put(conn, ~p"/galleries/#{gallery}", %{"gallery" => %{"title" => "Renamed via PUT"}})

      assert redirected_to(conn) == ~p"/galleries/#{gallery}"
      assert Philomena.Repo.reload!(gallery).title == "Renamed via PUT"
    end

    test "re-renders the form when the title is blank", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      gallery = gallery_fixture(user)

      conn = patch(conn, ~p"/galleries/#{gallery}", %{"gallery" => %{"title" => ""}})

      assert html_response(conn, 200) =~ "Editing Gallery"
      assert Philomena.Repo.reload!(gallery).title == gallery.title
    end

    test "redirects other users with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      gallery = gallery_fixture(confirmed_user_fixture())

      conn = patch(conn, ~p"/galleries/#{gallery}", %{"gallery" => %{"title" => "Hijacked"}})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Philomena.Repo.reload!(gallery).title == gallery.title
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      gallery = gallery_fixture(user)

      conn =
        patch(without_fingerprint(conn), ~p"/galleries/#{gallery}", %{
          "gallery" => %{"title" => "Renamed test gallery"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Philomena.Repo.reload!(gallery).title == gallery.title
    end
  end

  describe "DELETE /galleries/:id" do
    test "destroys the gallery as its owner", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      gallery = gallery_fixture(user)

      conn = delete(conn, ~p"/galleries/#{gallery}")

      assert redirected_to(conn) == ~p"/galleries"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Gallery successfully destroyed."
      assert Philomena.Repo.reload(gallery) == nil
    end

    test "redirects other users with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      gallery = gallery_fixture(confirmed_user_fixture())

      conn = delete(conn, ~p"/galleries/#{gallery}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Philomena.Repo.reload(gallery) == nil
    end

    test "redirects banned users with the ban flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

      conn = delete(conn, ~p"/galleries/999999999")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
    end
  end
end
