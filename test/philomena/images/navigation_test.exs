defmodule Philomena.Images.NavigationTest do
  @moduledoc """
  Context-level tests for the image navigation loaders on `Philomena.Images`:
  prev/next lookup, the search-index page number, related images, and the
  random-image picker.

  All four run a search scoped to a viewer, so they are asserted against the
  real OpenSearch index. Each parses and loads its subject image before `:show`
  authorization, so malformed and missing ids are consistently not found for
  every actor.
  """

  use Philomena.DataCase, async: false

  @moduletag :search

  import Philomena.ImagesFixtures
  import Philomena.AttributionFixtures
  import Philomena.UsersFixtures

  alias Philomena.Images
  alias Philomena.Images.Image
  alias Philomena.Images.Search.Scope
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers

  setup do
    Search.clear_index!(Image)
    :ok
  end

  # The compiled filter body the web layer produces for a viewer with no active
  # filter: an empty tag_ids exclusion plus a pair of match_none clauses, so it
  # excludes nothing.
  defp default_filter do
    %{
      bool: %{
        should: [
          %{terms: %{tag_ids: []}},
          %{bool: %{should: [%{match_none: %{}}, %{match_none: %{}}]}}
        ]
      }
    }
  end

  defp scope(overrides \\ []) do
    Scope.new(
      Keyword.get(overrides, :filter, default_filter()),
      Keyword.get(overrides, :pagination, %{page_number: 1, page_size: 25}),
      Keyword.get(overrides, :params, %{})
    )
  end

  defp hours_ago(hours) do
    DateTime.utc_now()
    |> DateTime.add(-hours * 3600, :second)
    |> DateTime.truncate(:second)
  end

  # Two images ordered by first_seen_at, the default descending sort; `newer`
  # precedes `older` in the listing.
  defp two_images do
    older = image_fixture(first_seen_at: hours_ago(2))
    newer = image_fixture(first_seen_at: hours_ago(1))
    SearchHelpers.reindex_all!(Image)

    {older, newer}
  end

  describe "list_image_navigation/2" do
    test "rel=next finds the older image and carries a sort cursor" do
      {older, newer} = two_images()

      assert {:ok, {image, {adjacent, hit}}} =
               Images.list_image_navigation(
                 actor(),
                 scope(params: %{"rel" => "next"}),
                 to_string(newer.id)
               )

      assert image.id == newer.id
      assert adjacent.id == older.id
      assert Map.has_key?(hit, "sort")
    end

    test "rel=prev finds the newer image" do
      {older, newer} = two_images()

      assert {:ok, {image, {adjacent, _hit}}} =
               Images.list_image_navigation(
                 actor(),
                 scope(params: %{"rel" => "prev"}),
                 to_string(older.id)
               )

      assert image.id == older.id
      assert adjacent.id == newer.id
    end

    test "returns a nil neighbor at the end of the sequence" do
      {older, _newer} = two_images()

      assert {:ok, {image, nil}} =
               Images.list_image_navigation(
                 actor(),
                 scope(params: %{"rel" => "next"}),
                 to_string(older.id)
               )

      assert image.id == older.id
    end

    test "accepts an integer id" do
      {older, newer} = two_images()

      assert {:ok, {image, {adjacent, _hit}}} =
               Images.list_image_navigation(actor(), scope(params: %{"rel" => "next"}), newer.id)

      assert image.id == newer.id
      assert adjacent.id == older.id
    end

    test "an unknown well-formed id is not found for an anonymous viewer" do
      # Missing image locators resolve to not-found before authorization.
      assert Images.list_image_navigation(
               actor(),
               scope(params: %{"rel" => "next"}),
               "2147483647"
             ) ==
               {:error, :not_found}
    end

    test "an unknown well-formed id is not found for an admin" do
      # Missing image locators resolve to not-found before authorization.
      admin = admin_user_fixture()
      scope = scope(params: %{"rel" => "next"})

      assert Images.list_image_navigation(actor(admin), scope, "2147483647") ==
               {:error, :not_found}
    end

    test "a non-castable id is not found" do
      assert Images.list_image_navigation(
               actor(),
               scope(params: %{"rel" => "next"}),
               "not-a-number"
             ) ==
               {:error, :not_found}
    end
  end

  describe "list_image_index_page/2" do
    test "returns the page number as an integer" do
      {older, newer} = two_images()

      # Listed by descending id, the newer image has no images ahead of it, so
      # it sits on page one; the older image trails it but still on page one at
      # the default page size.
      assert Images.list_image_index_page(actor(), scope(), to_string(newer.id)) == {:ok, 1}
      assert Images.list_image_index_page(actor(), scope(), to_string(older.id)) == {:ok, 1}
    end

    test "the scope's page size drives the page number" do
      {older, _newer} = two_images()

      # One image precedes the older one; a page size of one puts it on page two.
      scope = scope(pagination: %{page_number: 1, page_size: 1})

      assert Images.list_image_index_page(actor(), scope, to_string(older.id)) == {:ok, 2}
    end

    test "accepts an integer id" do
      {_older, newer} = two_images()

      assert Images.list_image_index_page(actor(), scope(), newer.id) == {:ok, 1}
    end

    test "an unknown well-formed id is not found for an anonymous viewer" do
      assert Images.list_image_index_page(actor(), scope(), "2147483647") ==
               {:error, :not_found}
    end

    test "a non-castable id is not found" do
      assert Images.list_image_index_page(actor(), scope(), "not-a-number") ==
               {:error, :not_found}
    end
  end

  describe "list_related_images/2" do
    test "an image sharing a tag lists the related image" do
      image = image_fixture(tags: "safe, test related subject")
      related = image_fixture(tags: "safe, test related subject")
      SearchHelpers.reindex_all!(Image)

      assert {:ok, {loaded, page}} =
               Images.list_related_images(actor(), scope(), to_string(image.id))

      assert loaded.id == image.id
      assert related.id in Enum.map(page.entries, & &1.id)
      # The subject image never appears among its own related results.
      refute image.id in Enum.map(page.entries, & &1.id)
    end

    test "an image with no shared tags still succeeds with an empty page" do
      # Only the rating tag is present, and ratings are excluded from matching,
      # so there is nothing to relate against.
      image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      assert {:ok, {loaded, page}} =
               Images.list_related_images(actor(), scope(), to_string(image.id))

      assert loaded.id == image.id
      assert page.entries == []
    end

    test "accepts an integer id" do
      image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      assert {:ok, {loaded, _page}} = Images.list_related_images(actor(), scope(), image.id)
      assert loaded.id == image.id
    end

    test "an unknown well-formed id is not found for an anonymous viewer" do
      assert Images.list_related_images(actor(), scope(), "2147483647") == {:error, :not_found}
    end

    test "an unknown well-formed id is not found for an admin" do
      assert Images.list_related_images(actor(admin_user_fixture()), scope(), "2147483647") ==
               {:error, :not_found}
    end

    test "a non-castable id is not found" do
      assert Images.list_related_images(actor(), scope(), "not-a-number") == {:error, :not_found}
    end
  end

  describe "list_random_images/1" do
    test "returns the id of the only matching image" do
      image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      assert Images.list_random_images(actor(), scope()) == {:ok, image.id}
    end

    test "returns nil when the index is empty" do
      assert Images.list_random_images(actor(), scope()) == {:ok, nil}
    end

    test "restricts the pool to the q parameter" do
      _other = image_fixture(tags: "safe")
      wanted = image_fixture(tags: "safe, test wanted tag")
      SearchHelpers.reindex_all!(Image)

      assert Images.list_random_images(actor(), scope(params: %{"q" => "test wanted tag"})) ==
               {:ok, wanted.id}
    end

    test "returns an explicit error for a malformed query string" do
      # An unbalanced parenthesis fails to compile, and the picker treats a
      # malformed query as an empty pool.
      _image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      assert {:error, _message} =
               Images.list_random_images(actor(), scope(params: %{"q" => "((("}))
    end
  end
end
