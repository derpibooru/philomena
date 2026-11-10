defmodule Philomena.Images.QueryTest do
  use ExUnit.Case, async: true

  alias Philomena.Images.Query
  alias PhilomenaQuery.Parse.Parser

  @user %{
    id: 1,
    role: "user",
    watched_tag_ids: [],
    settings: %{
      watched_images_query_str: "",
      watched_images_exclude_str: "",
      no_spoilered_in_watched: false
    }
  }

  describe "compile/2 with my:upvotes" do
    test "returns a term query for the user's upvoter_ids" do
      assert {:ok, %{term: %{upvoter_ids: 1}}} = Query.compile("my:upvotes", user: @user)
    end

    test "returns an error for anonymous users" do
      assert {:error, _} = Query.compile("my:upvotes", user: nil)
    end
  end

  describe "compile/2 with my:subs" do
    test "returns a term query for the user's subscriber_ids" do
      assert {:ok, %{term: %{subscriber_ids: 1}}} = Query.compile("my:subs", user: @user)
    end

    test "returns an error for anonymous users" do
      assert {:error, _} = Query.compile("my:subs", user: nil)
    end
  end

  describe "compile/2 with my:watched" do
    test "reads the watchlist query strings from the user's settings" do
      assert {:ok, %{bool: %{should: should, must_not: _must_not}}} =
               Query.compile("my:watched", user: @user)

      # the watched-tags clause always contributes the user's watched_tag_ids
      assert %{terms: %{tag_ids: []}} in should
    end

    test "returns an error for anonymous users" do
      assert {:error, _} = Query.compile("my:watched", user: nil)
    end
  end

  describe "compile_with_tag_names/2" do
    test "collects unique tags from nested positive and negative clauses" do
      assert {:ok, %{query: query, tag_names: names}} =
               Query.compile_with_tag_names("safe AND (cute OR -artist:Example) AND safe")

      assert is_map(query)
      assert Enum.sort(names) == ["artist:example", "cute", "safe"]
    end

    test "leaves out tags from the user's watchlist queries" do
      user = %{
        @user
        | settings: %{
            @user.settings
            | watched_images_query_str: "cute OR artist:example",
              watched_images_exclude_str: "-grimdark"
          }
      }

      assert {:ok, %{query: query, tag_names: names}} =
               Query.compile_with_tag_names("safe AND my:watched", user: user)

      # The watchlist still applies to the query itself.
      assert "cute" in Parser.referenced_term_values(query, "tags")
      assert names == ["safe"]
    end

    test "returns the normal parser error for malformed input" do
      assert {:error, message} = Query.compile_with_tag_names("width.gte:abc")
      assert is_binary(message)
    end
  end
end
