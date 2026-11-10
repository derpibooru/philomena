defmodule PhilomenaWeb.Image.RandomControllerTest do
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

  describe "GET /images/random" do
    test "redirects to a random image", %{conn: conn} do
      image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/images/random")

      assert redirected_to(conn) == ~p"/images/#{image.id}?"
    end

    test "redirects to the image index when nothing matches", %{conn: conn} do
      conn = get(conn, ~p"/images/random")

      assert redirected_to(conn) == ~p"/images"
    end

    test "restricts the pool with a search query", %{conn: conn} do
      _safe = image_fixture(tags: "safe")
      wanted = image_fixture(tags: "safe, test wanted tag")
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/images/random?q=test wanted tag")

      assert redirected_to(conn) == ~p"/images/#{wanted.id}?#{[q: "test wanted tag"]}"
    end
  end
end
