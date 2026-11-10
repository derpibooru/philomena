defmodule PhilomenaWeb.Api.Json.Search.ImageControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  @moduletag :search

  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Multi
  alias Philomena.ImageFaves
  alias Philomena.Images.Image
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers

  setup do
    Search.clear_index!(Image)
    :ok
  end

  defp response_image_ids(conn) do
    %{"images" => images} = json_response(conn, 200)
    Enum.map(images, & &1["id"])
  end

  describe "GET /api/v1/json/search/images" do
    test "finds images matching a tag query", %{conn: conn} do
      safe = image_fixture(tags: "safe")
      _solo = image_fixture(tags: "solo")
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/api/v1/json/search/images?q=safe")

      assert %{"total" => 1, "interactions" => []} = json_response(conn, 200)
      assert response_image_ids(conn) == [safe.id]
    end

    test "excludes hidden and unapproved images", %{conn: conn} do
      visible = image_fixture()
      _hidden = image_fixture(hidden_from_users: true)
      _unapproved = image_fixture(approved: false)
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/api/v1/json/search/images?q=safe")

      assert %{"total" => 1} = json_response(conn, 200)
      assert response_image_ids(conn) == [visible.id]
    end

    test "sorts by the sf and sd parameters", %{conn: conn} do
      first = image_fixture()
      second = image_fixture()
      SearchHelpers.reindex_all!(Image)

      conn1 = get(conn, ~p"/api/v1/json/search/images?q=safe&sf=id&sd=asc")
      assert response_image_ids(conn1) == [first.id, second.id]

      conn2 = get(conn, ~p"/api/v1/json/search/images?q=safe&sf=id&sd=desc")
      assert response_image_ids(conn2) == [second.id, first.id]
    end

    test "paginates with page and per_page", %{conn: conn} do
      for _ <- 1..3, do: image_fixture()
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/api/v1/json/search/images?q=safe&per_page=2&page=2")

      assert %{"images" => [_], "total" => 3} = json_response(conn, 200)
    end

    test "returns the user's interactions for an API key", %{conn: conn} do
      user = confirmed_user_fixture()
      image = image_fixture()

      {:ok, _} =
        Multi.new()
        |> ImageFaves.put_fave_for_loaded_image(image, user)
        |> Multi.transact()

      SearchHelpers.reindex_all!(Image)

      conn =
        get(conn, ~p"/api/v1/json/search/images?q=safe&key=#{user.authentication_token}")

      assert %{"interactions" => interactions} = json_response(conn, 200)

      assert interactions == [
               %{
                 "image_id" => image.id,
                 "user_id" => user.id,
                 "interaction_type" => "faved",
                 "value" => ""
               }
             ]
    end

    test "returns an empty result for a missing query string", %{conn: conn} do
      _image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      # NOTE: a missing/empty q compiles to match_none, a 200 with no
      # results - not a 400.
      conn = get(conn, ~p"/api/v1/json/search/images")

      assert json_response(conn, 200) == %{"images" => [], "interactions" => [], "total" => 0}
    end

    test "returns 400 with a JSON error for an unparsable query", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/search/images?q=)")

      assert json_response(conn, 400) == %{"error" => "Imbalanced parentheses."}
    end
  end

  describe "GET /api/v1/json/search (alias)" do
    test "behaves like /search/images", %{conn: conn} do
      image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/api/v1/json/search?q=safe")

      assert %{"total" => 1} = json_response(conn, 200)
      assert response_image_ids(conn) == [image.id]
    end
  end
end
