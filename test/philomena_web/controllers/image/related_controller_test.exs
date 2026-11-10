defmodule PhilomenaWeb.Image.RelatedControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  @moduletag :search

  import Philomena.ImagesFixtures

  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers
  alias Philomena.Images.Image

  setup do
    Search.clear_index!(Image)
    :ok
  end

  describe "GET /images/:image_id/related" do
    test "lists images sharing tags with the image", %{conn: conn} do
      image = image_fixture(tags: "safe, test related subject")
      related = image_fixture(tags: "safe, test related subject")
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/images/#{image}/related")
      response = html_response(conn, 200)

      assert response =~ "##{image.id} - Related Images - Derpibooru"
      assert response =~ ~p"/images/#{related.id}"
    end

    test "renders when nothing is related", %{conn: conn} do
      image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/images/#{image}/related")

      assert html_response(conn, 200) =~ "##{image.id} - Related Images - Derpibooru"
    end

    test "redirects to / for an unknown image", %{conn: conn} do
      conn = get(conn, ~p"/images/999999999/related")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end
  end
end
